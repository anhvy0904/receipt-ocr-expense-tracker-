/**
 * ReceiptWise - Web Simulator & Interactive Engine
 * Emulates the On-device Flutter OCR & Expense Tracker experience
 */

// Brand Category Colors (Matching Flutter App theme)
const CATEGORY_COLORS = {
  'Food': '#425B9A',
  'Study': '#76C0EC',
  'Travel': '#FF95A5',
  'Gear': '#6982BA',
  'Entertainment': '#B96A80',
  'Other': '#8993A8'
};

const CATEGORY_NAMES_VI = {
  'Food': 'Ăn uống',
  'Study': 'Học tập',
  'Travel': 'Di chuyển',
  'Gear': 'Thiết bị',
  'Entertainment': 'Giải trí',
  'Other': 'Khác'
};

// 1. Receipt Parser Engine (JavaScript implementation of ReceiptParser from lib/services/receipt_parser.dart)
const ReceiptParserEngine = {
  accentsMap: {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ'
  },

  fold(text) {
    let result = (text || '').toLowerCase();
    for (const [plain, accented] of Object.entries(this.accentsMap)) {
      result = result.replace(new RegExp(`[${accented}]`, 'g'), plain);
    }
    return result.replace(/\s+/g, ' ').trim();
  },

  parseAmount(input) {
    if (!input) return null;
    let val = input.trim().replace(/\s+/g, '');
    val = val.replace(/(VND|VNĐ|đ|₫)$/i, '').trim();

    if (/^\d{1,3}(?:[.,]\d{3})+$/.test(val)) {
      val = val.replace(/[.,]/g, '');
    } else if (/^\d{1,3}(?:[.,]\d{3})+[.,]\d{1,2}$/.test(val)) {
      const splitIdx = Math.max(val.lastIndexOf('.'), val.lastIndexOf(','));
      val = val.substring(0, splitIdx).replace(/[.,]/g, '') + '.' + val.substring(splitIdx + 1);
    } else if (/^\d+(?:[.,]\d{1,2})?$/.test(val)) {
      val = val.replace(',', '.');
    } else {
      return null;
    }

    const parsed = parseFloat(val);
    return !isNaN(parsed) && isFinite(parsed) ? parsed : null;
  },

  parseDate(input) {
    if (!input) return null;
    const trimmed = input.trim();
    const dmy = /^(\d{1,2})([/.-])(\d{1,2})\2(\d{4})$/.exec(trimmed);
    const ymd = /^(\d{4})([/.-])(\d{1,2})\2(\d{1,2})$/.exec(trimmed);

    if (!dmy && !ymd) return null;
    const day = parseInt(dmy ? dmy[1] : ymd[4], 10);
    const month = parseInt(dmy ? dmy[3] : ymd[3], 10);
    const year = parseInt(dmy ? dmy[4] : ymd[1], 10);

    if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) return null;
    const d = new Date(year, month - 1, day);
    return (d.getFullYear() === year && d.getMonth() === month - 1 && d.getDate() === day) ? d : null;
  },

  detectCategory(text, merchant) {
    const combined = this.fold((merchant || '') + ' ' + (text || ''));
    if (/highland|phuc long|coffee|cafe|tra|noodle|pho|com|banh|coopmart|market|quan|an|food|lotteria|kfc|starbucks|pizza/i.test(combined)) {
      return 'Food';
    }
    if (/sach|fahasa|book|vo|but|hoc|course|tuition|pen|notebook/i.test(combined)) {
      return 'Study';
    }
    if (/grab|be|gojek|xang|petrolimex|taxi|ve xe|bus|flight|airline|travel/i.test(combined)) {
      return 'Travel';
    }
    if (/gear|thegioididong|fpt|phong vu|laptop|chuot|ban phim|headphone|phone|apple|samsung/i.test(combined)) {
      return 'Gear';
    }
    if (/cgv|cinema|lotte|rap|movie|karaoke|game|ticket|billiards/i.test(combined)) {
      return 'Entertainment';
    }
    return 'Other';
  },

  isPaymentScreenshot(rawText) {
    const folded = this.fold(rawText);
    const keywords = /\b(chuyen tien|chuyen khoan|giao dich|thanh toan|thanh cong|nguoi thu huong|tai khoan thu huong|ma giao dich|ma tra soat|so tien chuyen|vi dien tu|so du|bien lai dien tu)\b/i;
    const banks = /\b(vietcombank|techcombank|mb bank|mbbank|vietinbank|bidv|agribank|acb|vpbank|tpbank|cake|timo|momo|zalopay|viettel money|vnpay|shopeepay)\b/i;
    return banks.test(folded) || (folded.match(keywords) || []).length >= 2;
  },

  parsePayment(rawText) {
    const lines = rawText.split(/[\r\n]+/).map(l => l.trim()).filter(l => l.length > 0);
    const foldedAll = this.fold(rawText);

    let provider = null;
    let source = 'bankTransfer';
    const bankMatches = ['Vietcombank', 'Techcombank', 'MB Bank', 'VietinBank', 'BIDV', 'Agribank', 'ACB', 'VPBank', 'TPBank', 'Cake', 'Timo'];
    const walletMatches = ['MoMo', 'ZaloPay', 'Viettel Money', 'VNPay', 'ShopeePay'];

    for (const w of walletMatches) {
      if (foldedAll.includes(this.fold(w))) {
        provider = w;
        source = 'eWallet';
        break;
      }
    }
    if (!provider) {
      for (const b of bankMatches) {
        if (foldedAll.includes(this.fold(b))) {
          provider = b;
          source = 'bankTransfer';
          break;
        }
      }
    }

    let status = 'successful';
    let statusVi = 'Thành công';
    if (/\b(that bai|khong thanh cong|bi huy|loi giao dich|failed|cancelled)\b/i.test(foldedAll)) {
      status = 'failed';
      statusVi = 'Thất bại';
    } else if (/\b(dang xu ly|cho xu ly|dang cho|pending|processing)\b/i.test(foldedAll)) {
      status = 'pending';
      statusVi = 'Đang chờ xử lý';
    }

    let amount = null;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const folded = this.fold(line);
      if (/\b(so tien chuyen|so tien giao dich|so tien|amount|gia tri|so tien thanh toan)\b/i.test(folded)) {
        const amt = this.parseAmount(line);
        if (amt && amt > 0) {
          amount = amt;
          break;
        }
        if (i + 1 < lines.length) {
          const nextAmt = this.parseAmount(lines[i + 1]);
          if (nextAmt && nextAmt > 0) {
            amount = nextAmt;
            break;
          }
        }
      }
    }
    if (!amount) {
      for (const line of lines) {
        if (/(vnd|vnđ|đ|₫)$/i.test(line.trim())) {
          const amt = this.parseAmount(line);
          if (amt && amt > 0) {
            amount = amt;
            break;
          }
        }
      }
    }

    let recipient = null;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const folded = this.fold(line);
      if (/\b(nguoi nhan|nguoi thu huong|tai khoan thu huong|ten nguoi nhan|thanh toan cho|dich vu|den|to|recipient)\b/i.test(folded)) {
        const colonIdx = line.indexOf(':');
        if (colonIdx !== -1 && colonIdx + 1 < line.length) {
          const cand = line.substring(colonIdx + 1).trim();
          if (cand.length > 0) {
            recipient = cand;
            break;
          }
        }
        if (i + 1 < lines.length && !recipient) {
          recipient = lines[i + 1].trim();
          break;
        }
      }
    }
    if (!recipient) {
      for (const line of lines) {
        if (/^[A-ZÀ-Ỹ\s]{5,35}$/.test(line) && !/\b(VIETCOMBANK|TECHCOMBANK|MBBANK|BIDV|THANH CONG|GIAO DICH)\b/i.test(line)) {
          recipient = line.trim();
          break;
        }
      }
    }

    let date = null;
    const datesRegex = /\b(?:\d{1,2}[/.-]\d{1,2}[/.-]\d{4}|\d{4}[/.-]\d{1,2}[/.-]\d{1,2})\b/;
    for (const line of lines) {
      const m = line.match(datesRegex);
      if (m) {
        const d = this.parseDate(m[0]);
        if (d) {
          date = d;
          break;
        }
      }
    }

    let reference = null;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const folded = this.fold(line);
      if (/\b(ma giao dich|ma tra soat|ma tham chieu|so giao dich|ma gd|magd|ref|transaction id)\b/i.test(folded)) {
        const parts = line.split(/[:\-\s]+/);
        if (parts.length > 1) {
          reference = parts[parts.length - 1];
        }
        break;
      }
    }

    const category = this.detectCategory(rawText, recipient);

    return {
      merchant: recipient || (provider ? `Chuyển khoản ${provider}` : 'Giao dịch chuyển khoản'),
      amount: amount || 0,
      date: date || new Date(),
      category: category,
      source: source,
      provider: provider,
      status: status,
      statusVi: statusVi,
      reference: reference
    };
  },

  parse(rawText) {
    if (this.isPaymentScreenshot(rawText)) {
      return this.parsePayment(rawText);
    }

    const lines = rawText.split(/[\r\n]+/).map(l => l.trim()).filter(l => l.length > 0);
    let merchant = null;
    let amount = null;
    let date = null;

    const totals = /\b(?:tong (?:cong|tien|thanh toan)|thanh tien|thanh toan|cong tien|amount due|grand total|total)\b/i;
    const excluded = /\b(?:hoa don|receipt|invoice|dia chi|address|dien thoai|tel|dt|phone|mst|ma so thue|ngay|date|thu ngan|cashier)\b/i;
    const datesRegex = /\b(?:\d{4}[/.-]\d{1,2}[/.-]\d{1,2}|\d{1,2}[/.-]\d{1,2}[/.-]\d{4})\b/g;
    const moneyRegex = /-?\d+(?:[., ]\d{3})+(?:[.,]\d{1,2})?|-?\d+(?:[.,]\d{1,2})?/g;
    const currencyRegex = /(?<![\d.,])(-?\d{1,3}(?:[., ]\d{3})+(?:[.,]\d{1,2})?|-?\d+(?:[.,]\d{1,2})?)\s*(?:vnd|vnđ|đ|₫)/gi;
    const nonTotals = /\b(?:subtotal|sub total|tam tinh|tien khach|khach dua|tien thua|change|cash|vat|tax|giam gia|discount)\b/i;

    let currencyFallback = null;
    let bestTotalScore = -1;
    let bestDateScore = -1;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const folded = this.fold(line);

      // Date match
      const dateMatches = line.match(datesRegex);
      if (dateMatches) {
        for (const m of dateMatches) {
          const cand = this.parseDate(m);
          const score = /\b(?:ngay|date)\b/i.test(folded) ? 1 : 0;
          if (cand && score > bestDateScore) {
            date = cand;
            bestDateScore = score;
          }
        }
      }

      // Total Match
      const totalMatch = !nonTotals.test(folded) ? folded.match(totals) : null;
      if (totalMatch) {
        let amountText = folded.substring(totalMatch.index + totalMatch[0].length).trim();
        let adjacent = false;

        if (!moneyRegex.test(amountText) && i + 1 < lines.length) {
          const next = lines[i + 1];
          if (/^\s*[:=]?\s*-?\d[\d., ]*\s*(?:vnd|vnđ|đ|₫)?\s*$/i.test(next) && !next.match(datesRegex)) {
            amountText = next;
            adjacent = true;
          }
        }

        const priority = /\b(?:tong cong|tong tien|tong thanh toan|grand total|amount due)\b/i.test(folded)
          ? 4 : (folded.includes('thanh tien') ? 1 : 2);
        const score = priority * 2 + (adjacent ? 0 : 1);

        const candidates = amountText.match(moneyRegex);
        if (candidates) {
          for (const cand of candidates) {
            const val = this.parseAmount(cand);
            if (val && val > 0 && score >= bestTotalScore) {
              amount = val;
              bestTotalScore = score;
              break;
            }
          }
        }
      } else if (!nonTotals.test(folded) && currencyRegex.test(line) && !line.match(datesRegex)) {
        let m;
        const localRegex = new RegExp(currencyRegex.source, 'gi');
        while ((m = localRegex.exec(line)) !== null) {
          const val = this.parseAmount(m[1]);
          if (val && val > 0 && (currencyFallback === null || val > currencyFallback)) {
            currencyFallback = val;
          }
        }
      }

      // Merchant heuristic
      if (!merchant && this.isMerchantCandidate(line, totals, excluded, datesRegex, currencyRegex) && !nonTotals.test(folded)) {
        merchant = line;
      }
    }

    const finalAmount = amount !== null ? amount : currencyFallback;
    const category = this.detectCategory(rawText, merchant);

    return {
      merchant: merchant || 'Cửa hàng không tên',
      amount: finalAmount || 0,
      date: date || new Date(),
      category: category,
      source: 'receipt',
      provider: null,
      status: 'successful',
      statusVi: 'Thành công',
      reference: null
    };
  },

  isMerchantCandidate(line, totals, excluded, dates, currency) {
    const folded = this.fold(line);
    return !totals.test(folded) &&
      !excluded.test(folded) &&
      !line.match(dates) &&
      !currency.test(line) &&
      /[A-Za-zÀ-ỹ]/.test(line) &&
      !/^\d|https?:\/\/|www\./i.test(line);
  }
};

// 2. Pre-defined Realistic Sample Receipts
const SAMPLE_RECEIPTS = [
  {
    id: 'sample-1',
    name: 'Highlands Coffee',
    type: '🧾 Biên lai giấy',
    rawText: `HIGHLANDS COFFEE
Landmark 81, Binh Thanh, TP.HCM
Hoa don ban hang: HD-88492
Ngay: 15/05/2026 09:42
Thu ngan: Nguyen Van A
1. Phin Sua Da (L)       45.000
2. Banh Mi Que Ga        20.000
-------------------------------
Tong tien:               65.000 VND
Tien khach dua:         100.000 VND
Tien thua:               35.000 VND
Cam on quy khach & Hen gap lai!`
  },
  {
    id: 'sample-2',
    name: 'Vietcombank',
    type: '🏦 Chuyển khoản',
    rawText: `Vietcombank
CHUYỂN TIỀN THÀNH CÔNG
Số tiền: 500.000 VND
Người thụ hưởng: NGUYỄN VĂN A
Ngân hàng thụ hưởng: MB Bank
Ngày thực hiện: 18/05/2026 14:32:00
Mã giao dịch: VCB88492019
Nội dung: Tiền cơm trưa và đồ uống`
  },
  {
    id: 'sample-3',
    name: 'Ví MoMo',
    type: '📱 Ví điện tử',
    rawText: `MoMo
Giao dịch thành công
Số tiền: 120.000 đ
Thanh toán cho: Highlands Coffee
Thời gian: 15/05/2026 09:15
Mã giao dịch: MM987654321
Dịch vụ: Cà phê và điểm tâm sáng`
  },
  {
    id: 'sample-4',
    name: 'Co.opmart Thảo Điền',
    type: '🛒 Siêu thị',
    rawText: `SIEU THI CO.OPMART THAO DIEN
Xa Lo Ha Noi, TP. Thu Duc
Ngay mua hang: 14/05/2026 18:20
1. Sua tuoi Vinamilk     38.000
2. Thit heo xay 500g     72.000
3. Rau xa lach Da Lat    25.000
4. Nuoc giat OMO 2kg    110.000
-------------------------------
Tong cong thanh toan:   245.000 VND
Hinh thuc: Tien mat
Ma hoa don: CM-20260514-99`
  }
];

// Helper to draw realistic receipt / banking canvas image
function generateReceiptCanvas(receiptText, targetImgElement) {
  const canvas = document.createElement('canvas');
  canvas.width = 440;
  canvas.height = 600;
  const ctx = canvas.getContext('2d');

  const isBank = /vietcombank|mbbank|techcombank|chuyen tien/i.test(receiptText);
  const isWallet = /momo|zalopay/i.test(receiptText);

  if (isBank || isWallet) {
    const brandColor = isWallet ? '#A50064' : '#0B4127';
    const brandAccent = isWallet ? '#D82D8B' : '#16A34A';
    const brandName = isWallet ? 'VÍ ĐIỆN TỬ MOMO' : 'VIETCOMBANK DIGITAL';

    // Background
    ctx.fillStyle = '#F1F5F9';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Header gradient
    const grad = ctx.createLinearGradient(0, 0, canvas.width, 170);
    grad.addColorStop(0, brandColor);
    grad.addColorStop(1, isWallet ? '#C2185B' : '#15803D');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, canvas.width, 170);

    // App header title
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 15px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(brandName, canvas.width / 2, 45);

    // Checkmark circle
    ctx.beginPath();
    ctx.arc(canvas.width / 2, 110, 34, 0, Math.PI * 2);
    ctx.fillStyle = brandAccent;
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 36px sans-serif';
    ctx.textBaseline = 'middle';
    ctx.fillText('✓', canvas.width / 2, 110);

    // Title
    ctx.textBaseline = 'alphabetic';
    ctx.fillStyle = '#0F172A';
    ctx.font = 'bold 19px sans-serif';
    ctx.fillText('GIAO DỊCH THÀNH CÔNG', canvas.width / 2, 218);

    // Card details surface
    ctx.fillStyle = '#FFFFFF';
    ctx.strokeStyle = '#E2E8F0';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.roundRect(24, 240, canvas.width - 48, 330, 16);
    ctx.fill();
    ctx.stroke();

    // Text Lines inside card
    ctx.font = '14px sans-serif';
    ctx.fillStyle = '#334155';
    ctx.textAlign = 'left';

    const lines = receiptText.split('\n');
    let y = 280;
    for (const line of lines) {
      if (line.toLowerCase().includes('vietcombank') || line.toLowerCase().includes('momo')) continue;
      if (line.toLowerCase().includes('thanh cong')) continue;

      if (line.toLowerCase().includes('so tien')) {
        ctx.font = 'bold 18px sans-serif';
        ctx.fillStyle = brandAccent;
      } else {
        ctx.font = '13px sans-serif';
        ctx.fillStyle = '#334155';
      }
      ctx.fillText(line.trim(), 44, y);
      y += 30;
      if (y > canvas.height - 50) break;
    }

    targetImgElement.src = canvas.toDataURL('image/png');
    return;
  }

  // Paper texture
  ctx.fillStyle = '#FAFAF7';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Subtle border / shadow edge
  ctx.strokeStyle = '#E0DEC9';
  ctx.lineWidth = 2;
  ctx.strokeRect(4, 4, canvas.width - 8, canvas.height - 8);

  // Serrated top and bottom edges
  ctx.fillStyle = '#E8E4D6';
  for (let x = 0; x < canvas.width; x += 16) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + 8, 8);
    ctx.lineTo(x + 16, 0);
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(x, canvas.height);
    ctx.lineTo(x + 8, canvas.height - 8);
    ctx.lineTo(x + 16, canvas.height);
    ctx.fill();
  }

  // Draw Logo / Header Stamp
  ctx.fillStyle = '#253354';
  ctx.font = 'bold 22px Courier New, monospace';
  ctx.textAlign = 'center';
  ctx.fillText('*** BIÊN LAI BÁN HÀNG ***', canvas.width / 2, 50);

  // Draw Text Lines
  ctx.font = '15px Courier New, monospace';
  ctx.fillStyle = '#1D2536';
  ctx.textAlign = 'left';

  const lines = receiptText.split('\n');
  let y = 90;
  for (const line of lines) {
    if (line.includes('---')) {
      ctx.strokeStyle = '#A0AEC0';
      ctx.setLineDash([4, 2]);
      ctx.beginPath();
      ctx.moveTo(25, y - 5);
      ctx.lineTo(canvas.width - 25, y - 5);
      ctx.stroke();
      ctx.setLineDash([]);
      y += 18;
      continue;
    }
    if (line.toLowerCase().includes('tong')) {
      ctx.font = 'bold 16px Courier New, monospace';
      ctx.fillStyle = '#425B9A';
    } else {
      ctx.font = '14px Courier New, monospace';
      ctx.fillStyle = '#2D3748';
    }
    ctx.fillText(line, 25, y);
    y += 24;
    if (y > canvas.height - 70) break;
  }

  // Barcode at bottom
  const barcodeY = canvas.height - 55;
  ctx.fillStyle = '#111';
  let bx = 50;
  while (bx < canvas.width - 50) {
    const w = Math.floor(Math.random() * 3) + 1;
    ctx.fillRect(bx, barcodeY, w, 28);
    bx += w + Math.floor(Math.random() * 3) + 1;
  }

  targetImgElement.src = canvas.toDataURL('image/png');
}

// 3. Transactions State & Local Storage Management
const StateManager = {
  STORAGE_KEY: 'receiptwise_transactions_v1',
  transactions: [],

  init() {
    const saved = localStorage.getItem(this.STORAGE_KEY);
    if (saved) {
      try {
        this.transactions = JSON.parse(saved);
      } catch (e) {
        this.transactions = this.getDefaults();
      }
    } else {
      this.transactions = this.getDefaults();
      this.save();
    }
  },

  getDefaults() {
    return [
      {
        id: 1,
        merchant: 'Highlands Coffee - Landmark 81',
        amount: 65000,
        date: '2026-05-15',
        category: 'Food',
        createdAt: '2026-05-15T09:42:00Z'
      },
      {
        id: 2,
        merchant: 'Co.opmart Thảo Điền',
        amount: 245000,
        date: '2026-05-14',
        category: 'Food',
        createdAt: '2026-05-14T18:20:00Z'
      },
      {
        id: 3,
        merchant: 'Nhà Sách FAHASA',
        amount: 180000,
        date: '2026-05-12',
        category: 'Study',
        createdAt: '2026-05-12T14:15:00Z'
      },
      {
        id: 4,
        merchant: 'GrabBike Chuyến đi',
        amount: 32000,
        date: '2026-05-11',
        category: 'Travel',
        createdAt: '2026-05-11T08:30:00Z'
      }
    ];
  },

  save() {
    localStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.transactions));
  },

  addTransaction(t) {
    const newTx = {
      id: Date.now(),
      merchant: t.merchant,
      amount: Number(t.amount),
      date: t.date,
      category: t.category,
      createdAt: new Date().toISOString()
    };
    this.transactions.unshift(newTx);
    this.save();
    return newTx;
  },

  deleteTransaction(id) {
    this.transactions = this.transactions.filter(t => t.id !== id);
    this.save();
  },

  getStats() {
    const totalAllTime = this.transactions.reduce((sum, t) => sum + (t.amount || 0), 0);
    const count = this.transactions.length;

    // Recent 7 days logic
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const recentTotal = this.transactions
      .filter(t => new Date(t.date) >= sevenDaysAgo)
      .reduce((sum, t) => sum + (t.amount || 0), 0);

    return {
      totalAllTime,
      recentTotal: recentTotal || totalAllTime,
      count
    };
  },

  getCategoryTotals() {
    const map = {};
    for (const cat of Object.keys(CATEGORY_COLORS)) {
      map[cat] = 0;
    }
    for (const t of this.transactions) {
      const c = t.category || 'Other';
      map[c] = (map[c] || 0) + (t.amount || 0);
    }
    return map;
  },

  getWeekdayTotals() {
    // 7 days: T2, T3, T4, T5, T6, T7, CN
    const days = [
      { name: 'T2', total: 0 },
      { name: 'T3', total: 0 },
      { name: 'T4', total: 0 },
      { name: 'T5', total: 0 },
      { name: 'T6', total: 0 },
      { name: 'T7', total: 0 },
      { name: 'CN', total: 0 }
    ];

    for (const t of this.transactions) {
      const d = new Date(t.date);
      let dayIndex = d.getDay(); // 0 is Sunday, 1 is Monday...
      dayIndex = dayIndex === 0 ? 6 : dayIndex - 1; // Map to 0 (T2) -> 6 (CN)
      if (dayIndex >= 0 && dayIndex < 7) {
        days[dayIndex].total += t.amount;
      }
    }
    return days;
  }
};

// 4. Formatting Helpers
function formatVND(amount) {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
    maximumFractionDigits: 0
  }).format(amount || 0);
}

function formatDateDisplay(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return dateStr;
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}/${month}/${year}`;
}

// 5. Canvas Chart Painters (Port of CategoryDonutPainter & WeeklyBarChart)
function renderDonutChart(canvas, categoryTotals) {
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const size = canvas.width;
  ctx.clearRect(0, 0, size, size);

  const total = Object.values(categoryTotals).reduce((a, b) => a + b, 0);
  const cx = size / 2;
  const cy = size / 2;
  const outerRadius = (size / 2) - 10;
  const innerRadius = outerRadius * 0.62;

  if (total === 0) {
    // Draw empty gray ring
    ctx.beginPath();
    ctx.arc(cx, cy, outerRadius, 0, Math.PI * 2);
    ctx.arc(cx, cy, innerRadius, Math.PI * 2, 0, true);
    ctx.fillStyle = '#CBD5E1';
    ctx.fill();
    return;
  }

  let startAngle = -Math.PI / 2;

  for (const [cat, amt] of Object.entries(categoryTotals)) {
    if (amt <= 0) continue;
    const sliceAngle = (amt / total) * Math.PI * 2;
    const color = CATEGORY_COLORS[cat] || '#8993A8';

    ctx.beginPath();
    ctx.arc(cx, cy, outerRadius, startAngle, startAngle + sliceAngle);
    ctx.arc(cx, cy, innerRadius, startAngle + sliceAngle, startAngle, true);
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();

    startAngle += sliceAngle;
  }

  // Center text
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = document.documentElement.getAttribute('data-theme') === 'dark' ? '#FFF6DC' : '#253354';
  ctx.font = 'bold 13px Plus Jakarta Sans, sans-serif';
  ctx.fillText('Tổng cộng', cx, cy - 10);
  ctx.font = 'bold 15px Plus Jakarta Sans, sans-serif';
  ctx.fillStyle = '#425B9A';
  if (document.documentElement.getAttribute('data-theme') === 'dark') {
    ctx.fillStyle = '#76C0EC';
  }
  ctx.fillText(formatVND(total).replace('₫', '').trim() + ' ₫', cx, cy + 12);
}

function renderBarChart(canvas, weekdayDays) {
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const width = canvas.width;
  const height = canvas.height;
  ctx.clearRect(0, 0, width, height);

  const maxVal = Math.max(...weekdayDays.map(d => d.total), 50000);
  const bottomPadding = 24;
  const topPadding = 16;
  const usableHeight = height - bottomPadding - topPadding;
  const barWidth = Math.floor((width - 40) / 7) - 6;

  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';

  weekdayDays.forEach((day, idx) => {
    const x = 20 + idx * (barWidth + 6);
    const fraction = day.total / maxVal;
    const barHeight = Math.max(fraction * usableHeight, 6);
    const y = height - bottomPadding - barHeight;

    // Bar background track
    ctx.fillStyle = isDark ? 'rgba(118, 192, 236, 0.1)' : '#F0EBD9';
    ctx.beginPath();
    ctx.roundRect(x, topPadding, barWidth, usableHeight, 4);
    ctx.fill();

    // Active Bar
    ctx.fillStyle = day.total > 0 ? (isDark ? '#76C0EC' : '#425B9A') : 'transparent';
    ctx.beginPath();
    ctx.roundRect(x, y, barWidth, barHeight, [4, 4, 0, 0]);
    ctx.fill();

    // Day Label
    ctx.textAlign = 'center';
    ctx.font = '600 11px Plus Jakarta Sans, sans-serif';
    ctx.fillStyle = isDark ? '#8E9DB8' : '#7E8DA5';
    ctx.fillText(day.name, x + barWidth / 2, height - 6);
  });
}

// 6. UI Interaction & Event Wiring
document.addEventListener('DOMContentLoaded', () => {
  StateManager.init();

  // Elements
  const themeToggleBtn = document.getElementById('theme-toggle-btn');
  const heroMockupImg = document.getElementById('hero-mockup-img');
  const chipLight = document.getElementById('chip-theme-light');
  const chipDark = document.getElementById('chip-theme-dark');

  const receiptViewport = document.getElementById('sim-receipt-viewport');
  const receiptImg = document.getElementById('sim-receipt-img');
  const sampleBtns = document.querySelectorAll('.sample-chip');
  const receiptUploadInput = document.getElementById('receipt-upload-input');

  const reviewMerchant = document.getElementById('review-merchant');
  const reviewAmount = document.getElementById('review-amount');
  const reviewDate = document.getElementById('review-date');
  const reviewCategory = document.getElementById('review-category');
  const btnSaveTx = document.getElementById('btn-save-transaction');

  const statAllTime = document.getElementById('stat-all-time');
  const stat7Days = document.getElementById('stat-7days');
  const statCount = document.getElementById('stat-count');

  const donutCanvas = document.getElementById('donut-canvas');
  const barCanvas = document.getElementById('bar-canvas');
  const historyContainer = document.getElementById('sim-history-items');

  const toastNotice = document.getElementById('toast-notice');

  // Set default form date to today
  if (reviewDate) {
    const today = new Date().toISOString().split('T')[0];
    reviewDate.value = today;
  }

  // Theme Toggling
  function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('receiptwise_theme', theme);
    if (themeToggleBtn) {
      themeToggleBtn.innerHTML = theme === 'dark' ? '☀️' : '🌙';
    }
    if (heroMockupImg) {
      heroMockupImg.src = theme === 'dark' ? 'docs/screenshots/home-dark.png' : 'docs/screenshots/home-light.png';
    }
    if (chipLight && chipDark) {
      chipLight.classList.toggle('active', theme === 'light');
      chipDark.classList.toggle('active', theme === 'dark');
    }
    updateDashboard();
  }

  const savedTheme = localStorage.getItem('receiptwise_theme') || 'light';
  setTheme(savedTheme);

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      setTheme(current === 'dark' ? 'light' : 'dark');
    });
  }

  if (chipLight) chipLight.addEventListener('click', () => setTheme('light'));
  if (chipDark) chipDark.addEventListener('click', () => setTheme('dark'));

  // Toast
  function showToast(msg) {
    if (!toastNotice) return;
    toastNotice.textContent = msg;
    toastNotice.classList.add('show');
    setTimeout(() => toastNotice.classList.remove('show'), 2800);
  }

  // Update UI Dashboard
  function updateDashboard() {
    const stats = StateManager.getStats();
    if (statAllTime) statAllTime.textContent = formatVND(stats.totalAllTime);
    if (stat7Days) stat7Days.textContent = formatVND(stats.recentTotal);
    if (statCount) statCount.textContent = stats.count + ' GD';

    // Charts
    const catTotals = StateManager.getCategoryTotals();
    renderDonutChart(donutCanvas, catTotals);

    const weekDays = StateManager.getWeekdayTotals();
    renderBarChart(barCanvas, weekDays);

    // History Table
    if (historyContainer) {
      historyContainer.innerHTML = '';
      if (StateManager.transactions.length === 0) {
        historyContainer.innerHTML = '<div style="text-align:center; padding:20px; color:var(--text-muted); font-size:0.85rem;">Chưa có giao dịch nào. Hãy quét biên lai phía trên!</div>';
      } else {
        StateManager.transactions.forEach(t => {
          const item = document.createElement('div');
          item.className = 'history-item';
          const catColor = CATEGORY_COLORS[t.category] || '#8993A8';
          const catName = CATEGORY_NAMES_VI[t.category] || t.category;

          item.innerHTML = `
            <div class="history-left">
              <span class="category-tag" style="background:${catColor}">${catName}</span>
              <div>
                <div class="history-merchant">${escapeHtml(t.merchant)}</div>
                <div class="history-date">${formatDateDisplay(t.date)}</div>
              </div>
            </div>
            <div class="history-right">
              <span class="history-amount">${formatVND(t.amount)}</span>
              <button class="btn-del" title="Xóa" data-id="${t.id}">✕</button>
            </div>
          `;
          historyContainer.appendChild(item);
        });

        // Attach delete events
        historyContainer.querySelectorAll('.btn-del').forEach(btn => {
          btn.addEventListener('click', (e) => {
            const id = Number(e.target.getAttribute('data-id'));
            StateManager.deleteTransaction(id);
            updateDashboard();
            showToast('Đã xóa giao dịch thành công!');
          });
        });
      }
    }
  }

  // Helper escape
  function escapeHtml(str) {
    return (str || '').replace(/[&<>"']/g, m => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    })[m]);
  }

  // Process Receipt (Scan Simulation)
  function processReceipt(text) {
    if (!receiptViewport) return;
    receiptViewport.classList.add('scanning');

    const duration = Math.floor(Math.random() * 200) + 180; // realistic 180 - 380 ms

    setTimeout(() => {
      receiptViewport.classList.remove('scanning');
      const parsed = ReceiptParserEngine.parse(text);

      if (reviewMerchant) reviewMerchant.value = parsed.merchant;
      if (reviewAmount) reviewAmount.value = parsed.amount;
      if (reviewDate) {
        const d = parsed.date;
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        reviewDate.value = `${y}-${m}-${day}`;
      }
      if (reviewCategory) reviewCategory.value = parsed.category;

      const sourceIcon = document.getElementById('sim-source-icon');
      const sourceTitle = document.getElementById('sim-source-title');
      const statusChip = document.getElementById('sim-status-chip');

      if (sourceIcon && sourceTitle && statusChip) {
        if (parsed.source === 'bankTransfer') {
          sourceIcon.textContent = '🏦';
          sourceTitle.textContent = parsed.provider ? `Chuyển khoản: ${parsed.provider}` : 'Chuyển khoản Ngân hàng';
          statusChip.textContent = parsed.statusVi || 'Thành công';
          statusChip.style.background = parsed.status === 'failed' ? 'rgba(239, 68, 68, 0.2)' : 'rgba(16, 185, 129, 0.2)';
          statusChip.style.color = parsed.status === 'failed' ? '#EF4444' : '#10B981';
        } else if (parsed.source === 'eWallet') {
          sourceIcon.textContent = '📱';
          sourceTitle.textContent = parsed.provider ? `Ví điện tử: ${parsed.provider}` : 'Ví điện tử';
          statusChip.textContent = parsed.statusVi || 'Thành công';
          statusChip.style.background = 'rgba(16, 185, 129, 0.2)';
          statusChip.style.color = '#10B981';
        } else {
          sourceIcon.textContent = '🧾';
          sourceTitle.textContent = 'Biên lai giấy';
          statusChip.textContent = 'Thành công';
          statusChip.style.background = 'rgba(16, 185, 129, 0.2)';
          statusChip.style.color = '#10B981';
        }
      }

      showToast(`⚡ Nhận diện thành công trong ${duration}ms!`);
    }, 700);
  }

  // Sample Receipt Buttons
  sampleBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      sampleBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const sampleId = btn.getAttribute('data-sample');
      const sample = SAMPLE_RECEIPTS.find(s => s.id === sampleId);
      if (sample && receiptImg) {
        generateReceiptCanvas(sample.rawText, receiptImg);
        processReceipt(sample.rawText);
      }
    });
  });

  // Initial render sample 1
  if (SAMPLE_RECEIPTS[0] && receiptImg) {
    generateReceiptCanvas(SAMPLE_RECEIPTS[0].rawText, receiptImg);
    const parsedInit = ReceiptParserEngine.parse(SAMPLE_RECEIPTS[0].rawText);
    if (reviewMerchant) reviewMerchant.value = parsedInit.merchant;
    if (reviewAmount) reviewAmount.value = parsedInit.amount;
    if (reviewCategory) reviewCategory.value = parsedInit.category;
  }

  // Upload Custom Image / File
  if (receiptUploadInput) {
    receiptUploadInput.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (event) => {
        if (receiptImg) receiptImg.src = event.target.result;
        sampleBtns.forEach(b => b.classList.remove('active'));

        // Generate synthetic receipt text for custom uploads based on filename
        const customText = `CỬA HÀNG ${file.name.toUpperCase().replace(/\.[^/.]+$/, "")}
Địa chỉ: TP. Hồ Chí Minh
Ngày: 16/05/2026
1. Hàng hóa dịch vụ      150.000
-------------------------------
Tổng tiền thanh toán:   150.000 VND
Cảm ơn quý khách!`;

        processReceipt(customText);
      };
      reader.readAsDataURL(file);
    });
  }

  if (receiptViewport) {
    receiptViewport.addEventListener('click', () => {
      if (receiptUploadInput) receiptUploadInput.click();
    });
  }

  // Save Transaction Form
  if (btnSaveTx) {
    btnSaveTx.addEventListener('click', (e) => {
      e.preventDefault();
      const merchant = reviewMerchant ? reviewMerchant.value.trim() : '';
      const amount = reviewAmount ? parseFloat(reviewAmount.value) : 0;
      const date = reviewDate ? reviewDate.value : '';
      const category = reviewCategory ? reviewCategory.value : 'Food';

      if (!merchant) {
        alert('Vui lòng nhập tên cửa hàng (Merchant)!');
        return;
      }
      if (!amount || amount <= 0) {
        alert('Số tiền chi tiêu phải lớn hơn 0!');
        return;
      }

      StateManager.addTransaction({
        merchant,
        amount,
        date: date || new Date().toISOString().split('T')[0],
        category
      });

      updateDashboard();
      showToast(`Đã lưu giao dịch "${merchant}" (${formatVND(amount)}) vào SQLite!`);
    });
  }

  // Screenshots Gallery Lightbox
  const lightboxModal = document.getElementById('lightbox-modal');
  const lightboxImg = document.getElementById('lightbox-img');
  const lightboxClose = document.getElementById('lightbox-close');

  document.querySelectorAll('.gallery-card').forEach(card => {
    card.addEventListener('click', () => {
      const img = card.querySelector('img');
      if (img && lightboxModal && lightboxImg) {
        lightboxImg.src = img.src;
        lightboxModal.classList.add('active');
      }
    });
  });

  if (lightboxClose && lightboxModal) {
    lightboxClose.addEventListener('click', () => lightboxModal.classList.remove('active'));
    lightboxModal.addEventListener('click', (e) => {
      if (e.target === lightboxModal) lightboxModal.classList.remove('active');
    });
  }

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && lightboxModal && lightboxModal.classList.contains('active')) {
      lightboxModal.classList.remove('active');
    }
  });

  // Gallery Filters
  const filterBtns = document.querySelectorAll('.gallery-filter .chip-btn');
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const filter = btn.getAttribute('data-filter');

      document.querySelectorAll('.gallery-card').forEach(card => {
        const cat = card.getAttribute('data-cat');
        if (filter === 'all' || cat === filter) {
          card.style.display = 'flex';
        } else {
          card.style.display = 'none';
        }
      });
    });
  });

  // Initial Dashboard Render
  updateDashboard();
});
