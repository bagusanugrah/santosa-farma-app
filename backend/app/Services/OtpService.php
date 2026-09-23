<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\OtpCode;
use App\Models\PasswordReset;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class OtpService
{
    /**
     * Send OTP to customer via WhatsApp or Email.
     */
    public function sendOtp(?Customer $customer, string $target, string $type = 'phone'): OtpCode
    {
        // Invalidate old OTPs for this target
        OtpCode::where('target', $target)
            ->whereNull('verified_at')
            ->delete();

        $code = (string) rand(100000, 999999);
        $expiresAt = now()->addMinutes(5);

        $otp = OtpCode::create([
            'customer_id' => $customer?->id,
            'type' => $type,
            'target' => $target,
            'code' => $code,
            'expires_at' => $expiresAt,
        ]);

        $message = "Kode verifikasi OTP Apotek Santosa Farma Anda adalah: *{$code}*. Berlaku selama 5 menit. Jangan bagikan kode ini kepada siapapun.";

        if ($type === 'phone') {
            $this->sendWhatsApp($target, $message);
        } else {
            $this->sendEmail($target, 'Kode Verifikasi OTP — Apotek Santosa Farma', $message);
        }

        return $otp;
    }

    /**
     * Verify OTP code for target.
     */
    public function verifyOtp(string $target, string $code): bool
    {
        $otp = OtpCode::where('target', $target)
            ->where('code', $code)
            ->whereNull('verified_at')
            ->where('expires_at', '>', now())
            ->first();

        if (!$otp) {
            return false;
        }

        $otp->update(['verified_at' => now()]);
        return true;
    }

    /**
     * Send Password Reset Link.
     */
    public function sendPasswordReset(Customer $customer, string $target, string $type): PasswordReset
    {
        PasswordReset::where('target', $target)
            ->whereNull('used_at')
            ->delete();

        $token = Str::random(40);
        $expiresAt = now()->addMinutes(30);

        $reset = PasswordReset::create([
            'customer_id' => $customer->id,
            'target' => $target,
            'token' => $token,
            'type' => $type,
            'expires_at' => $expiresAt,
        ]);

        $webBaseUrl = config('app.web_url', env('WEB_URL', 'http://localhost:3000'));
        $resetUrl = "{$webBaseUrl}/reset-password?token={$token}&target=" . urlencode($target);
        $message = "Halo {$customer->name}, Anda telah meminta reset password di Apotek Santosa Farma. Klik link berikut untuk mengatur password baru Anda: {$resetUrl} . Link berlaku selama 30 menit.";

        if ($type === 'phone') {
            $this->sendWhatsApp($target, $message);
        } else {
            $this->sendEmail($target, 'Link Reset Password — Apotek Santosa Farma', $message);
        }

        return $reset;
    }

    /**
     * Send WhatsApp message via Gateway (Fonnte / Wablas or log).
     */
    public function sendWhatsApp(string $phone, string $message): bool
    {
        // Format phone number to standard Indonesian format (62...)
        $phone = preg_replace('/[^0-9]/', '', $phone);
        if (str_starts_with($phone, '0')) {
            $phone = '62' . substr($phone, 1);
        } elseif (!str_starts_with($phone, '62')) {
            $phone = '62' . $phone;
        }

        $token = env('WA_GATEWAY_TOKEN');
        $provider = env('WA_GATEWAY_PROVIDER', 'fonnte');

        Log::info("[WhatsApp Gateway] Sending to {$phone}: {$message}");

        if (empty($token)) {
            Log::info("[WhatsApp Gateway] WA_GATEWAY_TOKEN not configured. Message logged locally.");
            return true;
        }

        try {
            if ($provider === 'fonnte') {
                $response = Http::withHeaders([
                    'Authorization' => $token,
                ])->post(env('WA_GATEWAY_URL', 'https://api.fonnte.com/send'), [
                    'target' => $phone,
                    'message' => $message,
                ]);
                return $response->successful();
            }
        } catch (\Exception $e) {
            Log::error("[WhatsApp Gateway Error] " . $e->getMessage());
        }

        return true;
    }

    /**
     * Send Email message.
     */
    public function sendEmail(string $email, string $subject, string $message): bool
    {
        Log::info("[Email Service] Sending to {$email}: {$subject} - {$message}");

        try {
            Mail::raw($message, function ($m) use ($email, $subject) {
                $m->to($email)->subject($subject);
            });
            return true;
        } catch (\Exception $e) {
            Log::error("[Email Service Error] " . $e->getMessage());
            return false;
        }
    }
}

