// Offscreen clipboard probe: detect retrieval without offering large data or
// touching the desktop clipboard. The editable native field is a positive control.
#include <QBitArray>
#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTest>
#include <cstdlib>
#include <cstdio>
#include <memory>

class ProbeMimeData final : public QMimeData {
public:
    explicit ProbeMimeData(int &reads) : reads(reads) {}
    QStringList formats() const override { return {QStringLiteral("text/plain")}; }
protected:
    QVariant retrieveData(const QString &, QMetaType) const override {
        ++reads;
        return QStringLiteral("clipboard probe");
    }
private:
    int &reads;
};

static void check(bool condition, const char *message) {
    if (!condition) { qCritical("%s", message); std::exit(1); }
}

int main(int argc, char **argv) {
    // Refuse to run against a real desktop clipboard, even if invoked directly.
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    check(argc == 2, "Expected repository path");
    QQmlEngine engine;
    const QUrl base = QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1]) + "/tests/probe.qml");
    auto create = [&](const QByteArray &body) {
        QQmlComponent component(&engine);
        component.setData("import QtQuick\nimport QtQuick.Controls\nimport \"../components\"\n" + body, base);
        auto object = std::unique_ptr<QObject>(component.create());
        if (!object) qCritical() << component.errors();
        check(bool(object), "Cannot create clipboard probe field");
        return object;
    };
    int reads = 0;
    auto clipboard = QGuiApplication::clipboard();
    {
        auto native = create("TextField {}");
        clipboard->setMimeData(new ProbeMimeData(reads));
        QCoreApplication::processEvents();
        check(reads > 0, "Positive control did not retrieve clipboard text; test is inconclusive");
    }
    reads = 0;
    {
        auto field = create("KeyboardTextField { width: 240; height: 40; value: \"typed\" }");
        check(reads == 0, "Creating keyboard field retrieved existing clipboard text");
        QQuickWindow window;
        auto item = qobject_cast<QQuickItem *>(field.get());
        check(item, "Field must be a Quick item");
        item->setParentItem(window.contentItem());
        window.resize(300, 100);
        window.show();
        for (int state = 0; state < 4; ++state) {
            item->setVisible(state != 0);
            item->setEnabled(state != 1);
            if (state == 3) item->forceActiveFocus();
            clipboard->setMimeData(new ProbeMimeData(reads));
            QCoreApplication::processEvents();
            check(field->property("readOnly").toBool(), "Native field became writable");
            check(!field->property("canPaste").toBool(), "Keyboard field advertised paste");
            check(reads == 0, "Clipboard changes retrieved text in keyboard field");
        }
        QTest::keyClick(&window, Qt::Key_V, Qt::ControlModifier);
        QTest::keyClick(&window, Qt::Key_Insert, Qt::ShiftModifier);
        QTest::mouseClick(&window, Qt::MiddleButton, Qt::NoModifier, QPoint(20, 20));
        check(QMetaObject::invokeMethod(field.get(), "paste"), "Missing native paste method");
        QCoreApplication::processEvents();
        check(reads == 0, "Paste attempt retrieved clipboard text");
        check(field->property("text").toString() == "typed", "Paste attempt changed text");
        item->setParentItem(nullptr);
    }
    clipboard->clear();
    std::printf("Clipboard: native positive control reads text; keyboard fields perform zero reads on creation, changes or paste attempts (Qt %s).\n", qVersion());
}
