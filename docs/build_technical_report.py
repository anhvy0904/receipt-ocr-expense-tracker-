"""Build the four-page technical report from verified project facts and UI fixtures."""
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image, Flowable

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output/pdf/receiptwise_technical_report.pdf"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
font_candidates = [
    (Path("C:/Windows/Fonts/arial.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")),
    (Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"), Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")),
]
regular, bold = "Helvetica", "Helvetica-Bold"
for normal_path, bold_path in font_candidates:
    if normal_path.exists() and bold_path.exists():
        pdfmetrics.registerFont(TTFont("ReportBody", str(normal_path)))
        pdfmetrics.registerFont(TTFont("ReportBold", str(bold_path)))
        regular, bold = "ReportBody", "ReportBold"
        break
pdfmetrics.registerFontFamily(regular, normal=regular, bold=bold, italic=regular, boldItalic=bold)
styles = getSampleStyleSheet()
styles.add(ParagraphStyle("Body", fontName=regular, fontSize=10, leading=15, spaceAfter=8, textColor=colors.HexColor("#25332D")))
styles.add(ParagraphStyle("TitleRW", fontName=bold, fontSize=29, leading=34, spaceAfter=14, textColor=colors.HexColor("#165C43")))
styles.add(ParagraphStyle("HeadingRW", fontName=bold, fontSize=15, leading=20, spaceBefore=12, spaceAfter=8, textColor=colors.HexColor("#165C43")))
styles.add(ParagraphStyle("SmallRW", fontName=regular, fontSize=8, leading=11, spaceAfter=5))
styles.add(ParagraphStyle("CaptionRW", fontName=regular, fontSize=8, leading=11, alignment=TA_CENTER))
story = []

def p(text, style="Body"):
    return Paragraph(text, styles[style])

def heading(text):
    story.append(p(text, "HeadingRW"))

def table(rows, widths):
    cells = [[p(str(cell), "SmallRW") for cell in row] for row in rows]
    result = Table(cells, colWidths=widths, hAlign="LEFT")
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E1EEE7")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#CEDBD3")),
    ]))
    return result

class Pipeline(Flowable):
    def __init__(self):
        super().__init__()
        self.width, self.height = 507, 110
    def draw(self):
        c = self.canv
        rows = [["Camera / gallery", "ML Kit Latin", "ReceiptParser", "Editable review"], ["Explicit Save", "Files + SQLite", "Provider state", "History + charts"]]
        for row_index, labels in enumerate(rows):
            y = 72 - row_index * 55
            for index, label in enumerate(labels):
                x = index * 128
                c.setFillColor(colors.HexColor("#E1EEE7"))
                c.setStrokeColor(colors.HexColor("#54866D"))
                c.roundRect(x, y, 113, 36, 5, fill=1, stroke=1)
                c.setFillColor(colors.HexColor("#165C43"))
                c.setFont(bold, 9)
                c.drawCentredString(x + 56.5, y + 14, label)
                if index < 3:
                    c.line(x + 116, y + 18, x + 126, y + 18)
                    c.line(x + 126, y + 18, x + 122, y + 21)
                    c.line(x + 126, y + 18, x + 122, y + 15)

story += [p("ReceiptWise", "TitleRW"), p("Technical report | Android | Version 1.1.0+3 | 3 October 2026", "SmallRW")]
heading("1. Product and scope")
story.append(p("ReceiptWise turns paper receipts into local expenses. Users capture with the live scanner or the system camera, choose an existing receipt image, or enter an expense manually. ML Kit recognizes Latin text on the device. Every extracted result is reviewed and validated before an explicit Save. No cloud OCR, account or paid API is used."))
heading("2. Architecture and data flow")
story.append(Pipeline())
story.append(p("The existing UI / services / repository / database / models separation remains. A small Provider layer exposes one immutable SQLite snapshot to Home, History and Analytics. Camera and OCR own their native resources; services own parsing, image processing and write coordination. Navigator retains the established routes."))
story.append(table([
    ["Layer", "Responsibility"],
    ["UI and app", "Material 3, editable forms, navigation, light/dark/system appearance and user confirmation."],
    ["Services", "Camera, picker recovery, native-resolution image processing, OCR, regex parsing, safe save/delete and analytics aggregation."],
    ["State", "TransactionState (Provider + ChangeNotifier): records, loading/error, summary and chart data; AppearanceState: current theme."],
    ["Repository / database", "sqflite CRUD and range queries, schema version 1, lazy connection with coordinated close/open."],
], [125, 382]))
heading("3. Implementation stack")
story.append(p("Flutter 3.47.5 / Dart 3.13.4; minimum project Flutter 3.44 / Dart 3.12; Android API 24+. Packages: camera, image_picker, google_mlkit_text_recognition, sqflite, provider, image, path_provider and path. Charts use Flutter Canvas and CustomPainter. Host persistence tests use SQLite FFI; an Android integration scenario uses native sqflite."))
story.append(PageBreak())

story += [p("OCR, parsing and storage", "TitleRW")]
heading("4. OCR and image handling")
story.append(p("The live scanner snapshots its frame geometry, captures once and maps preview cover/orientation into original image pixels. Cropping and JPEG encoding run outside the UI in an isolate. Picker images retain the full image because no scanner frame applies; EXIF orientation is baked into a temporary JPEG. Android lost-picker data is recovered for review, never automatically saved."))
story.append(p("OcrService owns a lazy TextRecognizer using TextRecognitionScript.latin and InputImage.fromFilePath. Requests are serialized and disposal waits for accepted work. Full text, blocks and lines are returned. OCR failure still opens manual review. Stopwatch duration is logged only in debug; no fixed latency guarantee is made."))
heading("5. ReceiptParser rules")
story.append(table([
    ["Field", "Heuristic and safe fallback"],
    ["Merchant", "First plausible header after excluding invoice/contact/address/date/total lines. Original accents are preserved."],
    ["Amount", "Accent-folded final-total labels outrank item totals. Accept a standalone next-line amount. Exclude subtotal, cash tendered and change from currency fallback. Support 150.000, 150,000, 150 000 and VND / VNĐ / đ."],
    ["Date", "Strict day-first and year-first formats with consistent slash, hyphen or dot separators. Prefer labelled dates; reject impossible dates."],
    ["Review", "Nullable extraction remains blank. Require merchant, positive finite amount, valid date and one of six categories. Nothing saves before confirmation."],
], [100, 407]))
heading("6. SQLite and receipt ownership")
story.append(p("transactions: id INTEGER PRIMARY KEY AUTOINCREMENT; merchant TEXT NOT NULL; amount REAL NOT NULL; date TEXT NOT NULL; category TEXT NOT NULL; receipt_image_path TEXT; created_at TEXT NOT NULL. A date index supports range queries. DateTime values use UTC ISO-8601 strings and local display."))
story.append(p("Save copies the temporary JPEG to a unique documents path, then inserts its path into SQLite. Insert failure rolls back only the uncommitted copy and retains the source. Manual records have a null image path. Edits retain image/creation metadata. Confirmed deletion removes the row first, then the file; file cleanup can be retried without repeating the SQL deletion."))
heading("7. CustomPainter analytics")
story.append(p("CategoryDonutPainter draws animated arcs for Food, Study, Travel, Gear, Entertainment and Other. WeeklyBarPainter draws animated rounded bars for the latest seven local calendar days. Aggregation occurs in AnalyticsService before painting. BigInt cents avoid total overflow; painters receive finite normalized geometry. Repaint checks compare drawing data, colors and progress. Reduced motion and zero/empty states are supported."))
story.append(PageBreak())

story += [p("UI evidence", "TitleRW"), p("Actual Flutter-rendered screens from the automated host flow. Fixture receipt and OCR text are synthetic test inputs; these are not physical-device screenshots or native OCR accuracy evidence.", "Body")]
def screenshot(name, caption):
    return [Image(str(ROOT / "docs/screenshots" / (name + ".png")), width=115, height=255), Spacer(1, 6), p(caption, "CaptionRW")]
screen_table = Table([
    [screenshot("home-light", "Home - light appearance"), screenshot("home-dark", "Home - dark appearance")],
    [screenshot("review", "Editable review before Save"), screenshot("weekly-bars", "Latest-seven-day CustomPainter bars")],
], colWidths=[253.5, 253.5])
screen_table.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("ALIGN", (0, 0), (-1, -1), "CENTER"), ("BOTTOMPADDING", (0, 0), (-1, -1), 12)]))
story.append(screen_table)
story.append(PageBreak())

story += [p("Verification and release", "TitleRW")]
heading("8. Automated evidence")
story.append(p("Run dart format ., flutter pub get, flutter analyze and flutter test. The shared receipt-flow scenario covers explicit review, a real SQLite insert, Provider refresh, editing, category/daily analytics, deletion and image-cleanup retry. Import tests cover camera/gallery selection, cancellation, invalid data rollback, OCR failure fallback and Android lost-data handling with test doubles."))
story.append(p("The same scenario is available under integration_test/receipt_flow_test.dart for native Android sqflite. Camera/image selection and OCR boundaries are replaced by deterministic fixtures in this scenario. Separate physical tests must establish actual camera and ML Kit behavior. Latest command results and the APK checksum are recorded in README.md and COURSE_READINESS.md."))
heading("9. Release signing and installation")
story.append(p("The release uses application ID com.anhvy.receiptwise and a dedicated RSA signing key, with credentials in ignored local files. Release builds require private signing configuration and do not silently use the debug certificate. Secure backups are required for future updates. The application ID differs from older sample debug builds; it installs separately and does not migrate their data."))
heading("10. Privacy and limitations")
story.append(p("OCR text is used in memory for review and is not persisted. Images and transactions remain local; application code uploads neither. SQLite/images are not separately encrypted; Android/device backup policy still applies. Recognition depends on lighting, focus and receipt layout. The parser is heuristic and cannot prove correctness. Screenshot/payment parsing, bilingual UI and iOS support are outside this course-core upgrade."))
heading("11. Remaining acceptance checks")
story.append(table([
    ["Deliverable", "Current evidence / remaining action"],
    ["Core source and tests", "Implemented, automated checks documented. GitHub source is maintained in the user's repository."],
    ["Signed release APK", "Dedicated signing configured; verify signature after build. Actual installation still needs an Android device."],
    ["Device demonstration", "No Android device was connected during this work. Test permission, camera/torch/focus, rotation, gallery recovery, airplane-mode OCR and restart persistence."],
    ["Screenshots / video", "Host-rendered fixture screenshots included. Replace/add real device captures; record a 2-3 minute demo using docs/DEMO_CHECKLIST.md."],
], [125, 382]))
heading("References and project documents")
story.append(p("ARCHITECTURE.md; COURSE_READINESS.md; docs/DEMO_CHECKLIST.md; docs/RELEASE_SIGNING.md. Scope reference: Vcoch27/receipt-ocr-expense-tracker course PRD at commit c473bc5. Project source: github.com/anhvy0904/receipt-ocr-expense-tracker-.", "SmallRW"))

def decorate(canvas, doc):
    canvas.setStrokeColor(colors.HexColor("#CEDBD3"))
    canvas.line(44, 805, 551, 805)
    canvas.setFont(regular, 8)
    canvas.setFillColor(colors.HexColor("#52685C"))
    canvas.drawString(44, 818, "RECEIPTWISE / TECHNICAL REPORT")
    canvas.drawString(44, 28, "Version 1.1.0+3 | 2026-10-03 | Automated evidence; device validation pending")
    canvas.drawRightString(551, 28, str(doc.page))

document = SimpleDocTemplate(str(OUTPUT), pagesize=A4, leftMargin=44, rightMargin=44, topMargin=52, bottomMargin=48, title="ReceiptWise technical report", author="ReceiptWise project")
document.build(story, onFirstPage=decorate, onLaterPages=decorate)
print(OUTPUT)
