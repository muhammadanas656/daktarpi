class FAQItem {
  final String question;
  final String answer;
  final String category;

  const FAQItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

const List<FAQItem> kFaqList = [
  // --- GENERAL / BOOKING ---
  FAQItem(
    category: "Booking",
    question: "How do I book an appointment?",
    answer: "To book an appointment, navigate to the Home screen, select a doctor or specialty, choose a suitable time slot, and tap 'Book Appointment'. You will receive a confirmation shortly.",
  ),
  FAQItem(
    category: "Booking",
    question: "Can I cancel or reschedule my appointment?",
    answer: "Yes. Go to the 'Appointments' tab, select the upcoming appointment, and tap 'Cancel' or 'Reschedule'. Please note that cancellations made less than 2 hours before the time may not be eligible for a refund.",
  ),
  FAQItem(
    category: "Booking",
    question: "What if the doctor cancels?",
    answer: "If a doctor cancels, you will be notified immediately via push notification and email. You will receive a full refund, and we will help you book with another available specialist.",
  ),
  FAQItem(
    category: "Payments",
    question: "How do refunds work?",
    answer: "Refunds for eligible cancellations are processed within 5-7 business days to your original payment method.",
  ),

  // --- ACCOUNT SECURITY / 2FA ---
  FAQItem(
    category: "Security",
    question: "How do I enable Two-Factor Authentication (2FA)?",
    answer: "Go to Settings > Two-Factor Authentication. Toggle the switch to ON, scan the QR code with an authenticator app (like Google Authenticator), and enter the verified code.",
  ),
  FAQItem(
    category: "Security",
    question: "I lost my phone! How do I access my account?",
    answer: "If your authenticator app is inaccessible, you can use one of your **Backup Codes**. On the verification screen, tap 'Lost your phone? Use Backup Code' and enter an 8-character code you saved during setup.",
  ),
  FAQItem(
    category: "Security",
    question: "What happens if I lose my backup codes too?",
    answer: "For your security, if you lose both your authenticator device and your backup codes, you will be permanently locked out of your account to protect your medical data. Please contact support immediately for identity verification options.",
  ),
  FAQItem(
    category: "Security",
    question: "How do reset my password?",
    answer: "On the Login screen, tap 'Forgot Password?'. Enter your registered email to receive an 8-digit OTP code to reset your password.",
  ),

  // --- GENERAL ---
  FAQItem(
    category: "General",
    question: "Is my medical data safe?",
    answer: "Absolutely. DaktarPi uses strictly enforced Row Level Security (RLS) and encryption. Only you and your authorized doctors can view your records. We never sell your data.",
  ),
  FAQItem(
    category: "General",
    question: "What should I do in an emergency?",
    answer: "Do NOT use DaktarPi for emergencies. If you have a medical emergency, call 911 or your local emergency number immediately.",
  ),
];
