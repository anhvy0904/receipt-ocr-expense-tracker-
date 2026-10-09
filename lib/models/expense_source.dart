/// Input source classification for expense tracking.
enum ExpenseSource {
  receipt,
  bankTransfer,
  eWallet;

  String get labelVi {
    switch (this) {
      case ExpenseSource.receipt:
        return 'Biên lai giấy';
      case ExpenseSource.bankTransfer:
        return 'Chuyển khoản Ngân hàng';
      case ExpenseSource.eWallet:
        return 'Ví điện tử';
    }
  }

  String get icon {
    switch (this) {
      case ExpenseSource.receipt:
        return '🧾';
      case ExpenseSource.bankTransfer:
        return '🏦';
      case ExpenseSource.eWallet:
        return '📱';
    }
  }
}

/// Transaction completion status from payment screenshots.
enum PaymentStatus {
  successful,
  pending,
  failed,
  unknown;

  String get labelVi {
    switch (this) {
      case PaymentStatus.successful:
        return 'Thành công';
      case PaymentStatus.pending:
        return 'Đang chờ xử lý';
      case PaymentStatus.failed:
        return 'Không thành công';
      case PaymentStatus.unknown:
        return 'Không rõ';
    }
  }
}
