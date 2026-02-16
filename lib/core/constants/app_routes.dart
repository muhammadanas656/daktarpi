/// Centralized route path constants.
///
/// Using these constants instead of raw strings prevents typos
/// and makes route refactoring a single-point change.
class AppRoutes {
  AppRoutes._(); // Prevent instantiation

  // Public / Auth
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';

  // Main tabs (shell routes)
  static const home = '/home';
  static const doctors = '/doctors';
  static const appointments = '/appointments';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';

  // Doctor details & lists
  static const popularDoctors = '/popular_doctors';
  static const featuredDoctors = '/featured_doctors';
  static const doctorDetails = '/doctor_details'; // append /:id
  static const specialtyDoctors = '/specialty_doctors'; // append /:id
  static const clinicDoctors = '/clinic_doctors'; // append /:id

  // Appointments flow
  static const appointmentBooking = '/appointment_booking';
  static const paymentMethod = '/payment_method';

  // Other
  static const privacyPolicy = '/privacy_policy';
  static const locationPermission = '/location_permission';

  /// Helper for parameterised doctor details route.
  static String doctorDetailsById(String id) => '/doctor_details/$id';

  /// Helper for parameterised specialty doctors route.
  static String specialtyDoctorsById(String id) => '/specialty_doctors/$id';

  /// Helper for parameterised clinic doctors route.
  static String clinicDoctorsById(String id) => '/clinic_doctors/$id';
}
