import importlib.util
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock


PROJECT_DIR = Path(__file__).resolve().parents[1]


class FakeBoundSignal:
    def __init__(self):
        self.emissions = []

    def connect(self, callback):
        self.callback = callback

    def emit(self, *args):
        self.emissions.append(args)


class FakeSignal:
    def __init__(self, *args):
        self.name = None

    def __set_name__(self, owner, name):
        self.name = f"_fake_signal_{name}"

    def __get__(self, instance, owner):
        if instance is None:
            return self
        signal = instance.__dict__.get(self.name)
        if signal is None:
            signal = FakeBoundSignal()
            instance.__dict__[self.name] = signal
        return signal


class FakeQThread:
    def __init__(self, parent=None):
        self.parent = parent

    def isRunning(self):
        return False


def load_app_module():
    qt_core = types.ModuleType("PySide6.QtCore")
    qt_core.QThread = FakeQThread
    qt_core.Signal = FakeSignal
    qt_core.QTimer = object
    qt_widgets = types.ModuleType("PySide6.QtWidgets")
    qt_widgets.QMainWindow = object
    py_side = types.ModuleType("PySide6")
    py_side.QtCore = qt_core
    py_side.QtWidgets = qt_widgets

    saved = {name: sys.modules.get(name) for name in ("PySide6", "PySide6.QtCore", "PySide6.QtWidgets")}
    sys.modules.update({
        "PySide6": py_side,
        "PySide6.QtCore": qt_core,
        "PySide6.QtWidgets": qt_widgets,
    })
    try:
        spec = importlib.util.spec_from_file_location("kandian_ocr_under_test", PROJECT_DIR / "kandian_ocr.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        for name, previous in saved.items():
            if previous is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = previous


class FakePixmap:
    def tobytes(self, file_type):
        return b"png"


class FakePage:
    def get_pixmap(self, matrix):
        return FakePixmap()


class FakeDocument:
    page_count = 2

    def load_page(self, index):
        return FakePage()

    def close(self):
        pass


class KandianOcrTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = load_app_module()

    def test_pdf_identity_is_stable_and_isolates_sources_and_replacements(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            first_pdf = root / "a" / "book.pdf"
            second_pdf = root / "b" / "book.pdf"
            first_pdf.parent.mkdir()
            second_pdf.parent.mkdir()
            first_pdf.write_bytes(b"same-pdf")
            second_pdf.write_bytes(b"same-pdf")
            first = self.app.pdf_result_dir(first_pdf, root / "results")
            self.assertEqual(first, self.app.pdf_result_dir(first_pdf, root / "results"))
            self.assertTrue(first.name.startswith("book__"))
            self.assertNotEqual(first, self.app.pdf_result_dir(second_pdf, root / "results"))
            first_pdf.write_bytes(b"replacement-pdf")
            self.assertNotEqual(first, self.app.pdf_result_dir(first_pdf, root / "results"))

    def test_large_pdf_identity_reads_only_bounded_samples(self):
        app = self.app
        with tempfile.TemporaryDirectory() as temp_dir:
            pdf_path = Path(temp_dir) / "large.pdf"
            with pdf_path.open("wb") as pdf:
                pdf.truncate(2 * 1024 * 1024 * 1024)
            bytes_read = 0

            class CountingFile:
                def __init__(self, path, mode):
                    self.source = open(path, mode)

                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    self.source.close()

                def seek(self, offset):
                    return self.source.seek(offset)

                def read(self, size):
                    nonlocal bytes_read
                    data = self.source.read(size)
                    bytes_read += len(data)
                    return data

            app.pdf_source_identity(pdf_path, open_file=CountingFile)
            self.assertLessEqual(bytes_read, 3 * app.PDF_SAMPLE_SIZE)

    def test_single_instance_lock_degrades_without_fcntl(self):
        app = self.app
        with mock.patch.object(app, "fcntl", None):
            self.assertIsNone(app.acquire_single_instance())

    def test_single_instance_lock_keeps_open_file(self):
        app = self.app
        calls = []

        class LockFile:
            closed = False

            def fileno(self):
                return 42

            def close(self):
                self.closed = True

        lock_file = LockFile()
        fake_fcntl = types.SimpleNamespace(
            LOCK_EX=1, LOCK_NB=2, flock=lambda fd, flags: calls.append((fd, flags)))
        with mock.patch.object(app, "fcntl", fake_fcntl), \
                mock.patch.object(app, "APP_LOCK_FILE",
                                  types.SimpleNamespace(open=lambda mode: lock_file)):
            acquired = app.acquire_single_instance()

        self.assertIs(acquired, lock_file)
        self.assertEqual(calls, [(42, 3)])
        self.assertFalse(lock_file.closed)

    def test_single_instance_lock_reports_busy_and_closes_file(self):
        app = self.app

        class LockFile:
            closed = False

            def fileno(self):
                return 42

            def close(self):
                self.closed = True

        def busy(descriptor, flags):
            raise BlockingIOError

        lock_file = LockFile()
        fake_fcntl = types.SimpleNamespace(LOCK_EX=1, LOCK_NB=2, flock=busy)
        with mock.patch.object(app, "fcntl", fake_fcntl), \
                mock.patch.object(app, "APP_LOCK_FILE",
                                  types.SimpleNamespace(open=lambda mode: lock_file)):
            acquired = app.acquire_single_instance()

        self.assertIs(acquired, False)
        self.assertTrue(lock_file.closed)

    def test_cancel_keeps_pages_and_existing_summaries_and_never_emits_done(self):
        app = self.app
        fake_fitz = types.SimpleNamespace(open=lambda path: FakeDocument(), Matrix=lambda x, y: (x, y))
        with mock.patch.dict(sys.modules, {"fitz": fake_fitz}), \
                mock.patch.object(app, "ocr_image_bytes") as ocr:
            with tempfile.TemporaryDirectory() as temp_dir:
                pdf_path = Path(temp_dir) / "source" / "book.pdf"
                out_dir = Path(temp_dir) / "results"
                pdf_path.parent.mkdir()
                pdf_path.write_bytes(b"source-pdf")
                thread = app.PdfOcrThread("test-token", "test-user", str(pdf_path), str(out_dir), {})
                result_dir = app.pdf_result_dir(pdf_path, out_dir)
                result_dir.mkdir(parents=True)
                (result_dir / "汇总.txt").write_text("stale", encoding="utf-8")
                (result_dir / "汇总.docx").write_bytes(b"stale")

                def cancel_after_first_page(*args, **kwargs):
                    thread.stop()
                    return True, "第一页"

                ocr.side_effect = cancel_after_first_page
                thread.run()

                self.assertTrue((result_dir / "page_0001.txt").exists())
                self.assertEqual((result_dir / "汇总.txt").read_text(encoding="utf-8"), "stale")
                self.assertEqual((result_dir / "汇总.docx").read_bytes(), b"stale")
                self.assertEqual(thread.sig_done.emissions, [])
                self.assertEqual(thread.sig_cancelled.emissions[-1][:5], (1, 2, 1, 0, 0))

    def test_stop_during_summary_keeps_both_old_summaries_and_never_emits_done(self):
        app = self.app
        fake_fitz = types.SimpleNamespace(open=lambda path: FakeDocument(), Matrix=lambda x, y: (x, y))
        with mock.patch.dict(sys.modules, {"fitz": fake_fitz}), \
                mock.patch.object(app, "ocr_image_bytes", return_value=(True, "正文")):
            with tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                pdf_path = root / "source" / "book.pdf"
                out_dir = root / "results"
                pdf_path.parent.mkdir()
                pdf_path.write_bytes(b"source-pdf")
                thread = app.PdfOcrThread("test-token", "test-user", pdf_path, out_dir, {})
                result_dir = app.pdf_result_dir(pdf_path, out_dir)
                result_dir.mkdir(parents=True)
                (result_dir / "汇总.txt").write_text("old txt", encoding="utf-8")
                (result_dir / "汇总.docx").write_bytes(b"old docx")
                def write_txt(page_dir, output_path, should_stop):
                    Path(output_path).write_text("new txt", encoding="utf-8")
                    return True

                def stop_during_docx(page_dir, output_path, should_stop):
                    Path(output_path).write_bytes(b"new docx")
                    thread.stop()
                    return False

                with mock.patch.object(app, "write_summary_txt", side_effect=write_txt), \
                        mock.patch.object(app, "write_summary_docx",
                                          side_effect=stop_during_docx):
                    thread.run()

                self.assertEqual((result_dir / "汇总.txt").read_text(encoding="utf-8"), "old txt")
                self.assertEqual((result_dir / "汇总.docx").read_bytes(), b"old docx")
                self.assertEqual(thread.sig_done.emissions, [])
                self.assertTrue(thread.sig_cancelled.emissions)
                self.assertEqual(list(result_dir.glob(".summary-*")), [])

    def test_active_threads_includes_pdf_quota_and_image_jobs(self):
        class Job:
            def __init__(self, running):
                self.running = running

            def isRunning(self):
                return self.running

        pdf_thread = Job(True)
        quota_thread = Job(False)
        image_thread = Job(True)
        window = types.SimpleNamespace(_threads=[pdf_thread, quota_thread, image_thread])
        active = self.app.MainWindow._active_threads(window)
        self.assertEqual(active, [pdf_thread, image_thread])

    def test_forget_thread_is_idempotent(self):
        job = object()
        window = types.SimpleNamespace(_threads=[job])
        self.app.MainWindow._forget_thread(window, job)
        self.app.MainWindow._forget_thread(window, job)
        self.assertEqual(window._threads, [])

    def test_finished_thread_is_waited_before_reference_is_removed(self):
        class FinishedJob:
            waited = False

            def wait(self):
                self.waited = True

        job = FinishedJob()
        window = types.SimpleNamespace(_threads=[job], _closing=True, closed=False)
        window.sender = lambda: job
        window.close = lambda: setattr(window, "closed", True)
        window._forget_thread = types.MethodType(self.app.MainWindow._forget_thread, window)
        window._active_threads = types.MethodType(self.app.MainWindow._active_threads, window)
        self.app.MainWindow._on_thread_finished(window)
        self.assertTrue(job.waited)
        self.assertEqual(window._threads, [])
        self.assertTrue(window.closed)

    def test_close_waits_for_all_jobs_and_cancels_pdf(self):
        class RunningJob:
            def isRunning(self):
                return True

        class Event:
            ignored = False

            def ignore(self):
                self.ignored = True

        pdf_thread = self.app.PdfOcrThread("test-token", "test-user", "book.pdf", "results", {})
        pdf_thread.isRunning = lambda: True
        quota_thread = RunningJob()
        image_thread = RunningJob()
        event = Event()
        window = types.SimpleNamespace(
            _threads=[pdf_thread, quota_thread, image_thread],
            _closing=False,
            enabled=True,
            title="",
        )
        window._active_threads = types.MethodType(self.app.MainWindow._active_threads, window)
        window.setEnabled = lambda enabled: setattr(window, "enabled", enabled)
        window.setWindowTitle = lambda title: setattr(window, "title", title)

        self.app.MainWindow.closeEvent(window, event)

        self.assertTrue(pdf_thread._stop_event.is_set())
        self.assertTrue(window._closing)
        self.assertFalse(window.enabled)
        self.assertTrue(event.ignored)
        self.assertIn("正在安全退出", window.title)


if __name__ == "__main__":
    unittest.main()
