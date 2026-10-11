import 'package:flutter/foundation.dart';
import '../core/config.dart';

/// MerchantRegController maintains registration state across steps 1–4
/// of merchant onboarding. If an authenticated merchant has a profile but
/// no business, the app uses this controller to resume at Step 2.
class MerchantRegController extends ChangeNotifier {
  // Step 1: Owner Details
  String ownerFullName = '';
  String ownerPhone = '';
  String ownerEmail = '';
  String ownerPassword = '';
  String enteredOtp = '';
  bool isOtpVerified = false;

  // Step 2: Business Info
  String businessName = '';
  String category = 'cafe';
  String subtitle = '';
  String bio = '';
  String address = 'San Jose de Buenavista, Antique';
  String businessPhone = '';
  String hours = 'Mon - Sat: 8:00 AM - 6:00 PM';
  double lat = demoShopLat;
  double lng = demoShopLng;
  double radiusMeters = 1500.0;

  // Step 3: Permits & Verification
  String? permitFilePath;
  String? permitFileName;
  String? uploadedPermitUrl;
  bool isUploadingPermit = false;

  // Step tracking
  int currentStep = 1;

  void setOwnerDetails({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) {
    ownerFullName = fullName;
    ownerPhone = phone;
    ownerEmail = email;
    ownerPassword = password;
    notifyListeners();
  }

  void setOtp(String otp) {
    enteredOtp = otp;
    isOtpVerified = otp == demoOtp;
    notifyListeners();
  }

  void setBusinessInfo({
    required String name,
    required String selectedCategory,
    String? sub,
    String? description,
    String? addr,
    String? phone,
    String? opHours,
    double? latitude,
    double? longitude,
    double? radius,
  }) {
    businessName = name;
    category = selectedCategory;
    if (sub != null) subtitle = sub;
    if (description != null) bio = description;
    if (addr != null) address = addr;
    if (phone != null) businessPhone = phone;
    if (opHours != null) hours = opHours;
    if (latitude != null) lat = latitude;
    if (longitude != null) lng = longitude;
    if (radius != null) radiusMeters = radius;
    notifyListeners();
  }

  void setPermitFile({required String path, required String name}) {
    permitFilePath = path;
    permitFileName = name;
    notifyListeners();
  }

  void setUploadedPermitUrl(String url) {
    uploadedPermitUrl = url;
    isUploadingPermit = false;
    notifyListeners();
  }

  void setUploading(bool uploading) {
    isUploadingPermit = uploading;
    notifyListeners();
  }

  void goToStep(int step) {
    currentStep = step;
    notifyListeners();
  }

  void reset() {
    ownerFullName = '';
    ownerPhone = '';
    ownerEmail = '';
    ownerPassword = '';
    enteredOtp = '';
    isOtpVerified = false;
    businessName = '';
    category = 'cafe';
    subtitle = '';
    bio = '';
    address = 'San Jose de Buenavista, Antique';
    businessPhone = '';
    hours = 'Mon - Sat: 8:00 AM - 6:00 PM';
    lat = demoShopLat;
    lng = demoShopLng;
    radiusMeters = 1500.0;
    permitFilePath = null;
    permitFileName = null;
    uploadedPermitUrl = null;
    isUploadingPermit = false;
    currentStep = 1;
    notifyListeners();
  }
}
