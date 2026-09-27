/// API endpoint constants organized by backend module.
///
/// Paths are relative to [ApiClient.baseUrl] which already includes `/api`.
/// Auth endpoints are handled directly by [AuthService] and not listed here.
///
/// All routes match the NestJS backend controllers with global prefix `/api`:
///   /api/auth/*        → AuthService
///   /api/fleet/*       → ApiEndpoints.fleet
///   /api/trips/*       → ApiEndpoints.trips
///   /api/jobs/*        → ApiEndpoints.jobs
///   /api/services/*    → ApiEndpoints.services
///   /api/feeds/*       → ApiEndpoints.feeds
///   /api/lease/*       → ApiEndpoints.lease
///   /api/notifications → ApiEndpoints.notifications
///   /api/dashboard/*   → ApiEndpoints.dashboard
///   /api/kyc/*         → ApiEndpoints.kyc
///   /api/expenses/*    → ApiEndpoints.expenses
///   /api/calendar/*    → ApiEndpoints.calendar
///   /api/users/*       → ApiEndpoints.users
class ApiEndpoints {
  ApiEndpoints._();

  // ── Users / Profile ──────────────────────────────────────────────────────
  static const users = _UsersEndpoints();

  // ── Fleet (Vehicles & Drivers) ───────────────────────────────────────────
  static const fleet = _FleetEndpoints();

  // ── Trips ────────────────────────────────────────────────────────────────
  static const trips = _TripEndpoints();

  // ── Jobs ─────────────────────────────────────────────────────────────────
  static const jobs = _JobEndpoints();

  // ── Services ─────────────────────────────────────────────────────────────
  static const services = _ServiceEndpoints();

  // ── Feeds / Posts ─────────────────────────────────────────────────────────
  static const feeds = _FeedEndpoints();

  // ── Lease ────────────────────────────────────────────────────────────────
  static const lease = _LeaseEndpoints();

  // ── Notifications ────────────────────────────────────────────────────────
  static const notifications = _NotificationEndpoints();

  // ── Dashboard ────────────────────────────────────────────────────────────
  static const dashboard = _DashboardEndpoints();

  // ── KYC / Verification ───────────────────────────────────────────────────
  static const kyc = _KycEndpoints();

  // ── Expenses ─────────────────────────────────────────────────────────────
  static const expenses = _ExpensesEndpoints();

  // ── Calendar ─────────────────────────────────────────────────────────────
  static const calendar = _CalendarEndpoints();

  // ── Share Navigation ─────────────────────────────────────────────────────
  static const shareNavigation = _ShareNavigationEndpoints();

  // ── Learning ─────────────────────────────────────────────────────────────
  static const learning = _LearningEndpoints();

  // ── Issues (support tickets) ─────────────────────────────────────────────
  static const issues = _IssuesEndpoints();

  // ── Leads (service-provider CRM) ─────────────────────────────────────────
  static const leads = _LeadsEndpoints();

  // ── Enquiries (contact / service enquiry) ────────────────────────────────
  static const enquiries = _EnquiriesEndpoints();

  // ── Media (unified upload) ───────────────────────────────────────────────
  static const media = _MediaEndpoints();

  // ── Wallet & Earnings Withdrawals ────────────────────────────────────────
  static const wallet = _WalletEndpoints();

  // ── WheelBot AI Assistant ────────────────────────────────────────────────
  static const chat = _ChatEndpoints();
}

// ─────────────────────────────────────────────────────────────────────────────
// WheelBot AI Assistant
// ─────────────────────────────────────────────────────────────────────────────
class _ChatEndpoints {
  const _ChatEndpoints();

  // POST /chat  { messages, userId?, provider? }
  String get send => '/chat';
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet — earnings wallet & withdrawal requests (Professional + Service Provider)
// ─────────────────────────────────────────────────────────────────────────────
class _WalletEndpoints {
  const _WalletEndpoints();

  // GET  /wallet  → { availableBalance, pendingWithdrawals, totalEarned, totalWithdrawn }
  String get summary => '/wallet';

  // GET  /wallet/transactions?limit=  → ledger, latest first
  String get transactions => '/wallet/transactions';

  // GET  /wallet/withdrawals  → caller's withdrawal requests
  // POST /wallet/withdrawals  → create a withdrawal (claim earnings)
  String get withdrawals => '/wallet/withdrawals';
}

// ─────────────────────────────────────────────────────────────────────────────
// Media — unified upload endpoint
// ─────────────────────────────────────────────────────────────────────────────
class _MediaEndpoints {
  const _MediaEndpoints();

  // POST /media  (multipart `files`, or base64 `image`/`images`, optional `folder`)
  //   → { files: [{ url, key, contentType, folder, size }] }
  String get upload => '/media';
}

// ─────────────────────────────────────────────────────────────────────────────
// Enquiries
// ─────────────────────────────────────────────────────────────────────────────
class _EnquiriesEndpoints {
  const _EnquiriesEndpoints();

  // POST /enquiries/contact  { name, email, company?, phone?, subject?, message }
  String get contact => '/enquiries/contact';

  // POST /enquiries/service
  // { companyId?, serviceType, serviceLocation, currentChallenges, specialRequirements? }
  String get service => '/enquiries/service';
}

// ─────────────────────────────────────────────────────────────────────────────
// Share Navigation
// ─────────────────────────────────────────────────────────────────────────────
class _ShareNavigationEndpoints {
  const _ShareNavigationEndpoints();

  // POST /share-navigation/generate  { tripId } → { token, otp, shareUrl, expiresAt }
  String get generate => '/share-navigation/generate';

  // POST /share-navigation/verify  { token, otp }
  String get verify => '/share-navigation/verify';

  // GET  /share-navigation/:token/data
  String data(String token) => '/share-navigation/$token/data';
}

// ─────────────────────────────────────────────────────────────────────────────
// Users
// ─────────────────────────────────────────────────────────────────────────────
class _UsersEndpoints {
  const _UsersEndpoints();

  // GET  /users/profile          — current user profile (via auth token)
  String get profile => '/users/profile';

  // GET  /users/:userId/public-profile
  String publicProfile(String userId) => '/users/$userId/public-profile';

  // PUT  /settings/account/password
  String get changePassword => '/settings/account/password';

  // PUT  /users/profile  — update own profile
  String get updateProfile => '/users/profile';

  // PUT  /users/profile/transport  — company transport profile update
  String get updateTransportProfile => '/users/profile/transport';

  // PUT  /users/profile/professional
  String get updateProfessionalProfile => '/users/profile/professional';

  // POST /users/complete-transport  — finish transport company setup
  String get completeTransport => '/users/complete-transport';

  // Service Provider account + business profile are created via the shared
  // POST /auth/register and PUT /users/profile (see [updateProfile] above),
  // matching wheelboard-fe — no dedicated complete/update SP endpoints.

  // POST /users/professional-signup
  String get professionalSignUp => '/users/professional-signup';

  // POST /users/save-referral
  String get saveReferral => '/users/save-referral';

  // GET  /users/:userId/referrals
  String referralsByUser(String userId) => '/users/$userId/referrals';

  // GET  /users/:userId/profile  — fetch any user's profile by ID
  String userProfileById(String userId) => '/users/$userId/profile';
}

// ─────────────────────────────────────────────────────────────────────────────
// Fleet
// ─────────────────────────────────────────────────────────────────────────────
class _FleetEndpoints {
  const _FleetEndpoints();

  // ── Vehicles ───────────────────────────────────────────────────────────
  // POST   /fleet/vehicles
  String get addVehicle => '/fleet/vehicles';

  // GET    /fleet/vehicles
  String get vehicles => '/fleet/vehicles';

  // GET    /fleet/vehicles/:id
  String vehicleDetails(String id) => '/fleet/vehicles/$id';

  // GET    /fleet/vehicles/:id/gps-history
  String vehicleGpsHistory(String id) => '/fleet/vehicles/$id/gps-history';

  // PUT    /fleet/vehicles/:id
  String updateVehicle(String id) => '/fleet/vehicles/$id';

  // DELETE /fleet/vehicles/:id
  String deleteVehicle(String id) => '/fleet/vehicles/$id';

  // GET    /fleet/vehicles/verify/registration?registrationNumber=...
  // Pre-save RC lookup for the Add/Edit Vehicle form.
  String get verifyVehicleRegistration => '/fleet/vehicles/verify/registration';

  // GET    /fleet/vehicles/:id/rc-status
  //
  // Reads the vehicle's persisted RC state — never calls the KYC provider.
  // Vehicle Details and Fleet must use this rather than re-verifying on open.
  String vehicleRcStatus(String id) => '/fleet/vehicles/$id/rc-status';

  // POST   /fleet/vehicles/:id/verify-rc
  String verifyVehicleRc(String id) => '/fleet/vehicles/$id/verify-rc';

  // POST   /fleet/vehicles/:id/rc-manual-verification
  String vehicleRcManualVerification(String id) =>
      '/fleet/vehicles/$id/rc-manual-verification';

  // ── Drivers ───────────────────────────────────────────────────────────
  // POST   /fleet/drivers
  String get addDriver => '/fleet/drivers';

  // GET    /fleet/drivers
  String get drivers => '/fleet/drivers';

  // GET    /fleet/drivers/:id
  String driverDetails(String id) => '/fleet/drivers/$id';

  // PUT    /fleet/drivers/:id
  String updateDriver(String id) => '/fleet/drivers/$id';

  // DELETE /fleet/drivers/:id
  String deleteDriver(String id) => '/fleet/drivers/$id';

  // GET    /fleet/drivers/verify/license?licenseNumber=&dateOfBirth=
  // POST   /fleet/drivers/verify/license   multipart/form-data, field `document`
  //
  // Same path, two methods. The Add Driver form uses the GET lookup: a company
  // entering another person's details types the licence number and date of
  // birth, and rarely has that person's licence photo to hand. The POST upload
  // stays for the KYC flow, where the licence holder uploads their own.
  String get verifyDriverLicense => '/fleet/drivers/verify/license';

  // GET    /fleet/summary
  String get summary => '/fleet/summary';

  // GET    /fleet/drivers?companyId=...  — professionals linked to a company
  String professionalList(String companyId) =>
      '/fleet/drivers?companyId=$companyId';

  // GET    /fleet/drivers/:id  — alias used for professional profile detail
  String professionalDetails(String id) => '/fleet/drivers/$id';
}

// ─────────────────────────────────────────────────────────────────────────────
// Trips
// ─────────────────────────────────────────────────────────────────────────────
class _TripEndpoints {
  const _TripEndpoints();

  // POST   /trips
  String get create => '/trips';

  // GET    /trips  (supports ?status=, ?assigned=true, etc.)
  String get list => '/trips';

  // GET    /trips/:tripId
  String details(String tripId) => '/trips/$tripId';

  // PATCH  /trips/:tripId
  String update(String tripId) => '/trips/$tripId';

  // DELETE /trips/:tripId
  String delete(String tripId) => '/trips/$tripId';

  // POST   /trips/:tripId/sos
  //
  // Wheelboard's canonical SOS. Validates the trip, writes the audit entry,
  // marks the trip timeline, alerts the fleet owner and acknowledges the
  // driver. The driver identity comes from the access token — it is never
  // sent in the body. Accepts either the trip code or the trip row id.
  String sos(String tripId) => '/trips/$tripId/sos';

  // POST   /trips/:tripId/start
  String start(String tripId) => '/trips/$tripId/start';

  // POST   /trips/:tripId/arrive  — mark delivery complete
  String arrive(String tripId) => '/trips/$tripId/arrive';

  // POST   /trips/:tripId/pickup/start
  String pickupStart(String tripId) => '/trips/$tripId/pickup/start';

  // POST   /trips/:tripId/pickup/arrive
  String pickupArrive(String tripId) => '/trips/$tripId/pickup/arrive';

  // POST   /trips/:tripId/location  — GPS location update
  String updateLocation(String tripId) => '/trips/$tripId/location';

  // POST   /trips/:tripId/bid
  String submitBid(String tripId) => '/trips/$tripId/bid';

  // POST   /trips/:tripId/assign-bid
  String assignBid(String tripId) => '/trips/$tripId/assign-bid';

  // POST   /trips/:tripId/assign
  String assign(String tripId) => '/trips/$tripId/assign';

  // POST   /trips/:tripId/confirm-otp
  String confirmOtp(String tripId) => '/trips/$tripId/confirm-otp';

  // NOTE: there is no GET /trips/:tripId/bids route — bids are embedded in the
  // trip document (read `trip.bids` from GET /trips/:tripId). See trip_bids_controller.

  // GET    /trips  (unassigned — use list with queryParameters: {assigned: false})
  String get unassignedList => '/trips';

  // GET    /trips/:tripId  — alias used by unassigned trip detail screen
  String unassignedDetails(String tripId) => '/trips/$tripId';

  // GET    /trips/professional/stats
  String get professionalStats => '/trips/professional/stats';

  // ── Dashboard / Earnings ──────────────────────────────────────────────
  // Professional earnings come from `professionalStats` (GET /trips/professional/stats).
  // There is no /trips/earnings-dashboard route — do not re-add it.

  // GET    /trips/dashboard
  String get tripDashboard => '/trips/dashboard';

  // ── POD (Proof of Delivery) ───────────────────────────────────────────
  // POST   /trips/:tripId/pod/collect  — driver collects POD (multipart)
  String podCollect(String tripId) => '/trips/$tripId/pod/collect';

  // POST   /trips/:tripId/pod/collect-urls  — collect POD with pre-uploaded photo URLs (JSON)
  String podCollectUrls(String tripId) => '/trips/$tripId/pod/collect-urls';

  // POST   /trips/:tripId/pod  — professional uploads POD
  String podUpload(String tripId) => '/trips/$tripId/pod';

  // GET    /trips/:tripId/pod  — get POD details
  String podDetails(String tripId) => '/trips/$tripId/pod';

  // PATCH  /trips/:tripId/pod/verify  — company verifies or rejects POD
  String podVerify(String tripId) => '/trips/$tripId/pod/verify';

  // GET    /trips/:tripId/pod/download  — download POD document
  String podDownload(String tripId) => '/trips/$tripId/pod/download';

  // GET    /trips/pending-pod-verification  — list trips awaiting POD verification
  String get pendingPodVerification => '/trips/pending-pod-verification';

  // ── LR (Lorry Receipt) ────────────────────────────────────────────────
  // POST   /trips/:tripId/lr/generate  — generate LR (fleet owner, draft trip)
  String lrGenerate(String tripId) => '/trips/$tripId/lr/generate';

  // PATCH  /trips/:tripId/lr  — update LR after driver rejection (fleet owner)
  String lrUpdate(String tripId) => '/trips/$tripId/lr';

  // GET    /trips/:tripId/lr  — get LR details
  String lrDetails(String tripId) => '/trips/$tripId/lr';

  // POST   /trips/:tripId/lr/confirm  — driver confirms LR
  String lrConfirm(String tripId) => '/trips/$tripId/lr/confirm';

  // POST   /trips/:tripId/lr/request-otp  — driver requests OTP for LR confirmation
  String lrRequestOtp(String tripId) => '/trips/$tripId/lr/request-otp';

  // POST   /trips/:tripId/lr/verify-otp  — verify OTP and confirm LR
  String lrVerifyOtp(String tripId) => '/trips/$tripId/lr/verify-otp';

  // POST   /trips/:tripId/lr/reject  — driver rejects LR
  String lrReject(String tripId) => '/trips/$tripId/lr/reject';

  // ── Payment ───────────────────────────────────────────────────────────
  // POST   /payment/initiate  — create Razorpay order for trip payment
  String get createOrder => '/payment/initiate';

  // POST   /payment/verify  — verify Razorpay payment and assign trip
  String get verifyPayment => '/payment/verify';

  // GET    /trips/:tripId/payment/status  — payment confirmation details
  String confirmation(String tripId) => '/trips/$tripId/payment/status';
}

// ─────────────────────────────────────────────────────────────────────────────
// Jobs
// ─────────────────────────────────────────────────────────────────────────────
class _JobEndpoints {
  const _JobEndpoints();

  // ── Employer (Company/Business) ───────────────────────────────────────────
  // POST   /jobs
  String get create => '/jobs';

  // GET    /jobs/my-jobs
  String get myJobs => '/jobs/my-jobs';

  // GET    /jobs/my-jobs/stats
  String get myJobStats => '/jobs/my-jobs/stats';

  // GET    /jobs/my-jobs/:id
  String myJobDetails(String id) => '/jobs/my-jobs/$id';

  // PUT    /jobs/my-jobs/:id
  String updateJob(String id) => '/jobs/my-jobs/$id';

  // DELETE /jobs/my-jobs/:id
  String deleteJob(String id) => '/jobs/my-jobs/$id';

  // GET    /jobs/my-jobs/:id/applications
  String applications(String jobId) => '/jobs/my-jobs/$jobId/applications';

  // PATCH  /jobs/my-jobs/:jobId/applications/:applicationId
  String updateApplication(String jobId, String applicationId) =>
      '/jobs/my-jobs/$jobId/applications/$applicationId';

  // GET    /jobs/my-jobs/:jobId/applications/:applicationId/profile
  String applicantProfile(String jobId, String applicationId) =>
      '/jobs/my-jobs/$jobId/applications/$applicationId/profile';

  // ── Hired Professionals (employer) ────────────────────────────────────────
  // GET    /jobs/hired-professionals
  String get hiredProfessionals => '/jobs/hired-professionals';

  // GET    /jobs/hired-professionals/stats
  String get hiredProfessionalsStats => '/jobs/hired-professionals/stats';

  // PATCH  /jobs/hired-professionals/:professionalId/:jobId  (update status)
  // DELETE /jobs/hired-professionals/:professionalId/:jobId  (remove)
  String hiredProfessionalStatus(String professionalId, String jobId) =>
      '/jobs/hired-professionals/$professionalId/$jobId';

  // ── Professional ──────────────────────────────────────────────────────────
  // GET    /jobs/browse  — open marketplace for professionals
  String get browse => '/jobs/browse';

  // GET    /jobs/my-applications
  String get myApplications => '/jobs/my-applications';

  // GET    /jobs/my-saved
  String get mySavedJobs => '/jobs/my-saved';

  // GET    /jobs/:id
  String jobDetails(String id) => '/jobs/$id';

  // POST   /jobs/:id/apply
  String apply(String id) => '/jobs/$id/apply';

  // DELETE /jobs/:id/withdraw
  String withdraw(String id) => '/jobs/$id/withdraw';

  // POST   /jobs/:id/save  — bookmark a job (the only "like"/save mechanism)
  String saveJob(String id) => '/jobs/$id/save';

  // DELETE /jobs/:id/unsave
  String unsaveJob(String id) => '/jobs/$id/unsave';
}

// ─────────────────────────────────────────────────────────────────────────────
// Services
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceEndpoints {
  const _ServiceEndpoints();

  // POST   /services
  String get create => '/services';

  // GET    /services
  String get list => '/services';

  // GET    /services/:id
  String details(String id) => '/services/$id';

  // PATCH  /services/:id
  String update(String id) => '/services/$id';

  // DELETE /services/:id
  String delete(String id) => '/services/$id';

  // POST   /services/:id/publish
  String publish(String id) => '/services/$id/publish';

  // POST   /services/:id/unpublish
  String unpublish(String id) => '/services/$id/unpublish';

  // ── Bookings ──────────────────────────────────────────────────────────
  // POST   /services/bookings
  String get createBooking => '/services/bookings';

  // GET    /services/bookings/my
  String get myBookings => '/services/bookings/my';

  // GET    /services/bookings/service/:serviceId
  String bookingsByService(String serviceId) =>
      '/services/bookings/service/$serviceId';

  // GET    /services/bookings/provider/:providerId  — all bookings for a
  // provider in one call (backend resolves the provider from the JWT).
  String providerBookings(String providerId) =>
      '/services/bookings/provider/$providerId';

  // GET    /services/bookings/:id
  String bookingDetails(String id) => '/services/bookings/$id';

  // PATCH  /services/bookings/:id/status
  String updateBookingStatus(String id) => '/services/bookings/$id/status';

  // PATCH  /services/bookings/:id/start
  String startBooking(String id) => '/services/bookings/$id/start';

  // PATCH  /services/bookings/:id/complete
  String completeBooking(String id) => '/services/bookings/$id/complete';

  // PATCH  /services/bookings/:id/confirm-completion  — company confirms the
  // provider-completed service (consumer side; web servicesAPI.confirmCompanyCompletion)
  String confirmCompletion(String id) =>
      '/services/bookings/$id/confirm-completion';

  // GET    /services/bookings/company/:companyId  — bookings where the caller is
  // the consuming company
  String companyBookings(String companyId) =>
      '/services/bookings/company/$companyId';

  // POST   /services/bookings/:id/confirm-cash-payment
  String confirmCashPayment(String id) =>
      '/services/bookings/$id/confirm-cash-payment';

  // PATCH  /services/bookings/:id/payment-status
  String paymentStatus(String id) => '/services/bookings/$id/payment-status';

  // POST   /services/bookings/:id/payment/initiate
  String initiateBookingPayment(String id) =>
      '/services/bookings/$id/payment/initiate';

  // POST   /services/bookings/:id/payment/verify
  String verifyBookingPayment(String id) =>
      '/services/bookings/$id/payment/verify';

  // GET    /services/earnings/analytics
  String get earningsAnalytics => '/services/earnings/analytics';

  // POST   /services/payments/manual  — record manual (offline) payment
  // (backend route is /services/payments/manual, NOT /services/earnings/*)
  String get recordPayment => '/services/payments/manual';

  // GET    /services/payments/my  — payments recorded for the current user
  String get myPayments => '/services/payments/my';
}

// ─────────────────────────────────────────────────────────────────────────────
// Feeds
// ─────────────────────────────────────────────────────────────────────────────
class _FeedEndpoints {
  const _FeedEndpoints();

  // POST   /feeds
  String get create => '/feeds';

  // GET    /feeds
  String get list => '/feeds';

  // GET    /feeds/:id
  String details(String id) => '/feeds/$id';

  // PATCH  /feeds/:id
  String update(String id) => '/feeds/$id';

  // DELETE /feeds/:id
  String delete(String id) => '/feeds/$id';

  // POST   /feeds/:id/like
  String toggleLike(String id) => '/feeds/$id/like';

  // POST   /feeds/:id/comment
  String addComment(String id) => '/feeds/$id/comment';

  // DELETE /feeds/:id/comment/:commentId
  String deleteComment(String feedId, String commentId) =>
      '/feeds/$feedId/comment/$commentId';

  // POST   /feeds/:id/share
  String share(String id) => '/feeds/$id/share';

  // POST   /feeds/:id/report
  String report(String id) => '/feeds/$id/report';

  // POST   /feeds/upload-image
  String get uploadImage => '/feeds/upload-image';

  // GET    /feeds/stats
  String get stats => '/feeds/stats';
}

// ─────────────────────────────────────────────────────────────────────────────
// Lease
// ─────────────────────────────────────────────────────────────────────────────
class _LeaseEndpoints {
  const _LeaseEndpoints();

  // POST   /lease/listings
  String get createListing => '/lease/listings';

  // GET    /lease/listings/my
  String get myListings => '/lease/listings/my';

  // GET    /lease/listings/:id
  String listingDetails(String id) => '/lease/listings/$id';

  // PUT    /lease/listings/:id
  String updateListing(String id) => '/lease/listings/$id';

  // PATCH  /lease/listings/:id/status
  String updateListingStatus(String id) => '/lease/listings/$id/status';

  // GET    /lease/listings/:id/bookings  — bookings placed on one listing
  String listingBookings(String id) => '/lease/listings/$id/bookings';

  // GET    /lease/marketplace
  String get marketplace => '/lease/marketplace';

  // GET    /lease/marketplace/:id
  String marketplaceDetails(String id) => '/lease/marketplace/$id';

  // POST   /lease/marketplace/:id/availability  { startDate, endDate }
  String checkAvailability(String id) => '/lease/marketplace/$id/availability';

  // POST   /lease/bookings
  String get createBooking => '/lease/bookings';

  // GET    /lease/bookings/my
  String get myBookings => '/lease/bookings/my';

  // GET    /lease/bookings/incoming
  String get incomingBookings => '/lease/bookings/incoming';

  // GET    /lease/bookings/:id
  String bookingDetails(String id) => '/lease/bookings/$id';

  // PATCH  /lease/bookings/:id/confirm
  String confirmBooking(String id) => '/lease/bookings/$id/confirm';

  // PATCH  /lease/bookings/:id/reject
  String rejectBooking(String id) => '/lease/bookings/$id/reject';

  // PATCH  /lease/bookings/:id/cancel
  String cancelBooking(String id) => '/lease/bookings/$id/cancel';

  // PATCH  /lease/bookings/:id/start
  String startBooking(String id) => '/lease/bookings/$id/start';

  // PATCH  /lease/bookings/:id/complete
  String completeBooking(String id) => '/lease/bookings/$id/complete';
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationEndpoints {
  const _NotificationEndpoints();

  // GET    /notifications
  String get list => '/notifications';

  // PATCH  /notifications/:id/read
  String markRead(String id) => '/notifications/$id/read';

  // POST   /notifications/read-all
  String get readAll => '/notifications/read-all';

  // DELETE /notifications/:id
  String delete(String id) => '/notifications/$id';

  // POST   /notifications/register-device  { deviceId }  — store FCM token
  String get registerDevice => '/notifications/register-device';

  // DELETE /notifications/device/unregister  — clear FCM token on logout
  String get unregisterDevice => '/notifications/device/unregister';
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardEndpoints {
  const _DashboardEndpoints();

  // GET    /dashboard
  String get get => '/dashboard';

  // GET    /dashboard/stats
  String get stats => '/dashboard/stats';

  // GET    /dashboard/trip-completion-trend?range=7d|month|3month|all
  // Ranged, date-bucketed completion trend (backend owns the grouping) — the
  // same endpoint the web dashboard consumes so both platforms match.
  String tripCompletionTrend(String range) =>
      '/dashboard/trip-completion-trend?range=$range';
}

// ─────────────────────────────────────────────────────────────────────────────
// KYC
// ─────────────────────────────────────────────────────────────────────────────
class _KycEndpoints {
  const _KycEndpoints();

  // POST   /kyc
  String get create => '/kyc';

  // GET    /kyc/my-kyc
  String get myKyc => '/kyc/my-kyc';

  // PUT    /kyc
  String get update => '/kyc';

  // GET    /kyc/completeness
  String get completeness => '/kyc/completeness';

  // GET    /kyc/required-documents
  String get requiredDocuments => '/kyc/required-documents';

  // POST   /kyc/verify/pan
  String get verifyPan => '/kyc/verify/pan';

  // POST   /kyc/verify/driving-license   multipart/form-data, field `document`
  //
  // The current provider contract reads the licence from the licence DOCUMENT,
  // so this uploads the image/PDF. It is NOT a licence-number + DOB lookup.
  String get verifyDrivingLicense => '/kyc/verify/driving-license';

  // GET    /kyc/verify/driving-license/status
  //
  // Reads Wheelboard's persisted state ONLY — never calls the KYC provider.
  // Screens that merely display a status must use this.
  String get drivingLicenceStatus => '/kyc/verify/driving-license/status';

  // POST   /kyc/verify/driving-license/manual
  String get drivingLicenceManual => '/kyc/verify/driving-license/manual';

  // POST   /kyc/upload/document
  String get uploadDocument => '/kyc/upload/document';
}

// ─────────────────────────────────────────────────────────────────────────────
// Expenses
// ─────────────────────────────────────────────────────────────────────────────
class _ExpensesEndpoints {
  const _ExpensesEndpoints();

  // POST   /expenses
  String get create => '/expenses';

  // GET    /expenses
  String get list => '/expenses';

  // GET    /expenses/stats
  String get stats => '/expenses/stats';

  // GET    /expenses/recent
  String get recent => '/expenses/recent';

  // GET    /expenses/trip/:tripId/summary
  String tripSummary(String tripId) => '/expenses/trip/$tripId/summary';

  // GET    /expenses/:id
  String details(String id) => '/expenses/$id';

  // PATCH  /expenses/:id
  String update(String id) => '/expenses/$id';

  // DELETE /expenses/:id
  String delete(String id) => '/expenses/$id';

  // GET    /expenses/purposes  — expense categories/purpose list
  String get purposes => '/expenses/purposes';

  // GET    /expenses  — alias used by older controllers as expenseDetails
  String get expenseDetails => '/expenses';
}

// ─────────────────────────────────────────────────────────────────────────────
// Learning
// ─────────────────────────────────────────────────────────────────────────────
class _LearningEndpoints {
  const _LearningEndpoints();

  // GET    /learning  (supports ?category=)
  String get list => '/learning';

  // GET    /learning/categories
  String get categories => '/learning/categories';

  // GET    /learning/stats
  String get stats => '/learning/stats';

  // GET    /learning/:id
  String details(String id) => '/learning/$id';

  // POST   /learning/:id/enroll
  String enroll(String id) => '/learning/$id/enroll';

  // POST   /learning/:id/progress  { progress }
  String progress(String id) => '/learning/$id/progress';

  // POST   /learning/:id/rate  { rating }
  String rate(String id) => '/learning/$id/rate';

  // GET    /learning/:id/my-progress
  String myProgress(String id) => '/learning/$id/my-progress';

  // POST   /learning/:id/certificate  → { url }
  String certificate(String id) => '/learning/$id/certificate';
}

// ─────────────────────────────────────────────────────────────────────────────
// Issues (support tickets)
// ─────────────────────────────────────────────────────────────────────────────
class _IssuesEndpoints {
  const _IssuesEndpoints();

  // POST /issues  { title, description, category?, priority? }
  String get create => '/issues';

  // GET  /issues/my  — current user's reported issues
  String get myIssues => '/issues/my';

  // GET  /issues/:id
  String details(String id) => '/issues/$id';
}

// ─────────────────────────────────────────────────────────────────────────────
// Leads (service-provider CRM)
// ─────────────────────────────────────────────────────────────────────────────
class _LeadsEndpoints {
  const _LeadsEndpoints();

  // GET   /leads/provider/:providerId  (supports ?status=, ?source=)
  String providerLeads(String providerId) => '/leads/provider/$providerId';

  // GET   /leads/provider/:providerId/stats
  String providerStats(String providerId) =>
      '/leads/provider/$providerId/stats';

  // GET   /leads/:id
  String details(String id) => '/leads/$id';

  // PATCH /leads/:id/status   { status, notes? }
  String updateStatus(String id) => '/leads/$id/status';

  // PATCH /leads/:id/notes    { notes }
  String notes(String id) => '/leads/$id/notes';

  // PATCH /leads/:id/contact  { notes? }
  String contact(String id) => '/leads/$id/contact';

  // PATCH /leads/:id/convert  { notes? }
  String convert(String id) => '/leads/$id/convert';

  // PATCH /leads/:id/lost     { reason }
  String lost(String id) => '/leads/$id/lost';

  // PATCH /leads/:id/follow-up { date }
  String followUp(String id) => '/leads/$id/follow-up';
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarEndpoints {
  const _CalendarEndpoints();

  // POST   /calendar/events
  String get createEvent => '/calendar/events';

  // GET    /calendar/events
  String get events => '/calendar/events';

  // GET    /calendar/events/:id
  String eventDetails(String id) => '/calendar/events/$id';

  // PATCH  /calendar/events/:id
  String updateEvent(String id) => '/calendar/events/$id';

  // DELETE /calendar/events/:id
  String deleteEvent(String id) => '/calendar/events/$id';

  // GET    /calendar/stats
  String get stats => '/calendar/stats';
}
