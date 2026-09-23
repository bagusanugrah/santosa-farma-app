<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\OtpCode;
use App\Models\PasswordReset;
use App\Models\User;
use App\Services\OtpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    protected OtpService $otpService;

    public function __construct(OtpService $otpService)
    {
        $this->otpService = $otpService;
    }

    // ==========================================
    // STAFF AUTH (Super Admin & Admin Kasir)
    // ==========================================

    /**
     * Staff Login (Username & Password)
     */
    public function staffLogin(Request $request): JsonResponse
    {
        $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
        ]);

        $user = User::where('username', $request->username)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Username atau password salah.',
            ], 401);
        }

        // Delete old tokens and generate new
        $user->tokens()->delete();
        $token = $user->createToken('staff-token', ['role:' . $user->role])->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'Login berhasil.',
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'role' => $user->role,
                ],
            ],
        ]);
    }

    /**
     * Staff Me
     */
    public function staffMe(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'role' => $user->role,
            ],
        ]);
    }

    /**
     * Staff Logout
     */
    public function staffLogout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Berhasil logout.',
        ]);
    }

    // ==========================================
    // CUSTOMER AUTH (Web Client)
    // ==========================================

    /**
     * Customer Register (via Phone OR Email)
     */
    public function customerRegister(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'type' => 'required|in:phone,email',
            'phone' => 'nullable|string|max:20|unique:customers,phone',
            'email' => 'nullable|email|max:255|unique:customers,email',
            'password' => 'required|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $type = $request->type;
        $target = $type === 'phone' ? $request->phone : $request->email;

        if (empty($target)) {
            return response()->json([
                'status' => 'error',
                'message' => "Field {$type} wajib diisi.",
            ], 422);
        }

        // Create unverified customer
        $customer = Customer::create([
            'name' => $request->name,
            'phone' => $type === 'phone' ? $target : null,
            'email' => $type === 'email' ? $target : null,
            'password' => Hash::make($request->password),
        ]);

        // Send OTP
        $this->otpService->sendOtp($customer, $target, $type);

        return response()->json([
            'status' => 'success',
            'message' => "Registrasi berhasil. Kode OTP telah dikirimkan ke {$target}.",
            'data' => [
                'customer_id' => $customer->id,
                'target' => $target,
                'type' => $type,
            ],
        ], 201);
    }

    /**
     * Verify Customer OTP (for Register or Add Contact)
     */
    public function customerVerifyOtp(Request $request): JsonResponse
    {
        $request->validate([
            'target' => 'required|string',
            'code' => 'required|string|size:6',
            'type' => 'required|in:phone,email',
        ]);

        $verified = $this->otpService->verifyOtp($request->target, $request->code);

        if (!$verified) {
            return response()->json([
                'status' => 'error',
                'message' => 'Kode OTP tidak valid atau sudah kadaluarsa.',
            ], 400);
        }

        // Find customer
        $field = $request->type === 'phone' ? 'phone' : 'email';
        $customer = Customer::where($field, $request->target)->first();

        // If not found by target (e.g. adding email/phone to an existing account)
        if (!$customer) {
            $otpRecord = \App\Models\OtpCode::where('target', $request->target)
                ->where('code', $request->code)
                ->latest()
                ->first();

            if ($otpRecord && $otpRecord->customer_id) {
                $customer = Customer::find($otpRecord->customer_id);
            } elseif ($request->bearerToken() && $user = $request->user('sanctum')) {
                $customer = $user;
            }

            if ($customer) {
                if ($request->type === 'phone') {
                    $customer->phone = $request->target;
                    $customer->phone_verified_at = now();
                } else {
                    $customer->email = $request->target;
                    $customer->email_verified_at = now();
                }
                $customer->save();
            }
        } else {
            if ($request->type === 'phone') {
                $customer->update(['phone_verified_at' => now()]);
            } else {
                $customer->update(['email_verified_at' => now()]);
            }
        }

        if ($customer) {
            $customer->tokens()->delete();
            $token = $customer->createToken('customer-token', ['role:customer'])->plainTextToken;

            return response()->json([
                'status' => 'success',
                'message' => 'Verifikasi OTP berhasil.',
                'data' => [
                    'token' => $token,
                    'customer' => [
                        'id' => $customer->id,
                        'name' => $customer->name,
                        'phone' => $customer->phone,
                        'phone_verified' => !is_null($customer->phone_verified_at),
                        'email' => $customer->email,
                        'email_verified' => !is_null($customer->email_verified_at),
                    ],
                ],
            ]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'OTP terverifikasi.',
        ]);
    }

    /**
     * Resend Customer OTP
     */
    public function customerResendOtp(Request $request): JsonResponse
    {
        $request->validate([
            'target' => 'required|string',
            'type' => 'required|in:phone,email',
        ]);

        $field = $request->type === 'phone' ? 'phone' : 'email';
        $customer = Customer::where($field, $request->target)->first();

        $this->otpService->sendOtp($customer, $request->target, $request->type);

        return response()->json([
            'status' => 'success',
            'message' => "Kode OTP baru telah dikirimkan ke {$request->target}.",
        ]);
    }

    /**
     * Customer Login (by verified Phone OR Email + Password)
     */
    public function customerLogin(Request $request): JsonResponse
    {
        $request->validate([
            'login' => 'required|string', // phone or email
            'password' => 'required|string',
        ]);

        $login = trim($request->login);

        // Normalize phone variations if login looks like phone number
        $phoneAlternatives = [$login];
        $cleanDigits = preg_replace('/[^0-9]/', '', $login);
        if (!empty($cleanDigits)) {
            if (str_starts_with($cleanDigits, '0')) {
                $phoneAlternatives[] = '62' . substr($cleanDigits, 1);
            } elseif (str_starts_with($cleanDigits, '62')) {
                $phoneAlternatives[] = '0' . substr($cleanDigits, 2);
            }
            $phoneAlternatives[] = $cleanDigits;
        }

        $customer = Customer::where(function ($q) use ($login, $phoneAlternatives) {
            $q->where('email', strtolower($login))
              ->orWhereIn('phone', $phoneAlternatives);
        })->first();

        if (!$customer || !Hash::check($request->password, $customer->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'No. HP / Email atau password salah.',
            ], 401);
        }

        // Ensure at least the used login method is verified
        $isEmail = filter_var($login, FILTER_VALIDATE_EMAIL);
        if ($isEmail && is_null($customer->email_verified_at)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Email belum diverifikasi. Silakan lakukan verifikasi OTP terlebih dahulu.',
                'require_verification' => true,
                'target' => $customer->email,
                'type' => 'email',
            ], 403);
        }

        if (!$isEmail && is_null($customer->phone_verified_at)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Nomor HP belum diverifikasi. Silakan lakukan verifikasi OTP terlebih dahulu.',
                'require_verification' => true,
                'target' => $customer->phone,
                'type' => 'phone',
            ], 403);
        }

        $customer->tokens()->delete();
        $token = $customer->createToken('customer-token', ['role:customer'])->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'Login berhasil.',
            'data' => [
                'token' => $token,
                'customer' => [
                    'id' => $customer->id,
                    'name' => $customer->name,
                    'phone' => $customer->phone,
                    'phone_verified' => !is_null($customer->phone_verified_at),
                    'email' => $customer->email,
                    'email_verified' => !is_null($customer->email_verified_at),
                ],
            ],
        ]);
    }

    /**
     * Customer Profile
     */
    public function customerProfile(Request $request): JsonResponse
    {
        $customer = $request->user();

        return response()->json([
            'status' => 'success',
            'data' => [
                'id' => $customer->id,
                'name' => $customer->name,
                'phone' => $customer->phone,
                'phone_verified' => !is_null($customer->phone_verified_at),
                'email' => $customer->email,
                'email_verified' => !is_null($customer->email_verified_at),
                'created_at' => $customer->created_at,
            ],
        ]);
    }

    /**
     * Customer Update Profile Name
     */
    public function customerUpdateProfile(Request $request): JsonResponse
    {
        $customer = $request->user();

        $request->validate([
            'name' => 'required|string|max:255',
        ]);

        $customer->update(['name' => $request->name]);

        return response()->json([
            'status' => 'success',
            'message' => 'Profil berhasil diperbarui.',
            'data' => [
                'id' => $customer->id,
                'name' => $customer->name,
                'phone' => $customer->phone,
                'phone_verified' => !is_null($customer->phone_verified_at),
                'email' => $customer->email,
                'email_verified' => !is_null($customer->email_verified_at),
            ],
        ]);
    }

    /**
     * Customer Add or Update Contact (Phone / Email) — triggers OTP verification
     */
    public function customerAddContact(Request $request): JsonResponse
    {
        $customer = $request->user();

        $request->validate([
            'type' => 'required|in:phone,email',
            'target' => 'required|string',
        ]);

        $type = $request->type;
        $target = $request->target;

        // Check if target is already used by another customer
        $exists = Customer::where($type, $target)->where('id', '!=', $customer->id)->exists();
        if ($exists) {
            return response()->json([
                'status' => 'error',
                'message' => ucfirst($type) . ' tersebut sudah digunakan oleh akun lain.',
            ], 422);
        }

        // Send OTP to new contact
        $this->otpService->sendOtp($customer, $target, $type);

        return response()->json([
            'status' => 'success',
            'message' => "Kode OTP telah dikirimkan ke {$target}. Silakan verifikasi untuk mengaktifkan kontak.",
            'data' => [
                'target' => $target,
                'type' => $type,
            ],
        ]);
    }

    /**
     * Customer Verify Added Contact
     */
    public function customerVerifyAddContact(Request $request): JsonResponse
    {
        $customer = $request->user();

        $request->validate([
            'type' => 'required|in:phone,email',
            'target' => 'required|string',
            'code' => 'required|string|size:6',
        ]);

        $verified = $this->otpService->verifyOtp($request->target, $request->code);

        if (!$verified) {
            return response()->json([
                'status' => 'error',
                'message' => 'Kode OTP salah atau telah kadaluarsa.',
            ], 400);
        }

        if ($request->type === 'phone') {
            $customer->update([
                'phone' => $request->target,
                'phone_verified_at' => now(),
            ]);
        } else {
            $customer->update([
                'email' => $request->target,
                'email_verified_at' => now(),
            ]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Kontak berhasil diverifikasi dan ditambahkan ke profil Anda.',
            'data' => [
                'id' => $customer->id,
                'name' => $customer->name,
                'phone' => $customer->phone,
                'phone_verified' => !is_null($customer->phone_verified_at),
                'email' => $customer->email,
                'email_verified' => !is_null($customer->email_verified_at),
            ],
        ]);
    }

    /**
     * Customer Change Password (while authenticated)
     */
    public function customerChangePassword(Request $request): JsonResponse
    {
        $customer = $request->user();

        $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:8|confirmed',
        ], [
            'current_password.required' => 'Password saat ini wajib diisi.',
            'new_password.required' => 'Password baru wajib diisi.',
            'new_password.min' => 'Password baru minimal 8 karakter.',
            'new_password.confirmed' => 'Konfirmasi password baru tidak cocok.',
        ]);

        if (!Hash::check($request->current_password, $customer->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Password saat ini yang Anda masukkan salah.',
            ], 422);
        }

        $customer->update([
            'password' => Hash::make($request->new_password),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Password berhasil diperbarui.',
        ]);
    }

    /**
     * Forgot Password (Request Reset Link)
     */
    public function customerForgotPassword(Request $request): JsonResponse
    {
        $request->validate([
            'target' => 'required|string', // phone or email
        ]);

        $target = $request->target;
        $isEmail = filter_var($target, FILTER_VALIDATE_EMAIL);
        $type = $isEmail ? 'email' : 'phone';

        $customer = Customer::where($type, $target)->first();

        if (!$customer) {
            return response()->json([
                'status' => 'error',
                'message' => 'Akun dengan kontak tersebut tidak ditemukan.',
            ], 404);
        }

        $this->otpService->sendPasswordReset($customer, $target, $type);

        return response()->json([
            'status' => 'success',
            'message' => 'Link reset password telah dikirimkan ke ' . $target . '.',
        ]);
    }

    /**
     * Reset Password
     */
    public function customerResetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'token' => 'required|string',
            'target' => 'required|string',
            'password' => 'required|string|min:6',
        ]);

        $reset = PasswordReset::where('token', $request->token)
            ->where('target', $request->target)
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->first();

        if (!$reset) {
            return response()->json([
                'status' => 'error',
                'message' => 'Link reset password tidak valid atau sudah kadaluarsa.',
            ], 400);
        }

        $customer = Customer::find($reset->customer_id);
        if ($customer) {
            $customer->update([
                'password' => Hash::make($request->password),
            ]);
            $reset->update(['used_at' => now()]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Password berhasil diubah. Silakan login kembali dengan password baru.',
        ]);
    }
}

