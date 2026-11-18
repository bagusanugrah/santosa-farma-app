import nodemailer from 'nodemailer';
import { getIntegrationSettings } from './settings';

export function formatIndonesianPhone(phone: string): string {
  let clean = phone.replace(/[^0-9]/g, '');
  if (clean.startsWith('0')) {
    clean = '62' + clean.slice(1);
  } else if (!clean.startsWith('62')) {
    clean = '62' + clean;
  }
  return clean;
}

/**
 * Send WhatsApp message via Fonnte Gateway
 */
export async function sendWhatsApp(phone: string, message: string): Promise<boolean> {
  const settings = await getIntegrationSettings();
  const token = settings.fonnteToken;
  const url = settings.fonnteUrl;
  const target = formatIndonesianPhone(phone);

  console.log(`[WhatsApp Gateway] Sending to ${target}: ${message}`);

  if (!token) {
    console.warn('[WhatsApp Gateway] WA_GATEWAY_TOKEN is not configured.');
    return false;
  }

  try {
    const formData = new FormData();
    formData.append('target', target);
    formData.append('message', message);

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: token,
      },
      body: formData,
    });

    const json = await res.json().catch(() => null);
    console.log(`[WhatsApp Gateway] Response for ${target}:`, json);
    return res.ok && json?.status === true;
  } catch (err) {
    console.error('[WhatsApp Gateway Error]', err);
    return false;
  }
}

/**
 * Send Email via SMTP (Gmail)
 */
export async function sendEmail(
  to: string,
  subject: string,
  text: string,
  html?: string
): Promise<boolean> {
  const settings = await getIntegrationSettings();
  const user = settings.mailUser;
  const pass = settings.mailPass;
  const host = settings.mailHost;
  const port = settings.mailPort;
  const fromName = settings.mailFromName;

  console.log(`[Email Service] Sending to ${to}: ${subject}`);

  if (!user || !pass) {
    console.warn('[Email Service] MAIL_USERNAME or MAIL_PASSWORD is not configured.');
    return false;
  }

  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465, // true for 465 (SSL), false for 587 (STARTTLS)
      auth: {
        user,
        pass,
      },
    });

    const fromAddress = user;

    await transporter.sendMail({
      from: `"${fromName}" <${fromAddress}>`,
      to,
      subject,
      text,
      html:
        html ||
        `<p style="font-family: sans-serif; font-size: 16px; line-height: 1.5; color: #333;">${text.replace(
          /\n/g,
          '<br>'
        )}</p>`,
    });

    console.log(`[Email Service] Email successfully sent to ${to}`);
    return true;
  } catch (err) {
    console.error('[Email Service Error]', err);
    return false;
  }
}

/**
 * Unified OTP Dispatcher (WhatsApp or Email)
 */
export async function sendOtpNotification(
  target: string,
  type: 'phone' | 'email',
  code: string
): Promise<boolean> {
  const message = `Kode verifikasi OTP Apotek Santosa Farma Anda adalah: *${code}*. Berlaku selama 5 menit. Jangan bagikan kode ini kepada siapapun.`;

  if (type === 'phone') {
    return await sendWhatsApp(target, message);
  } else {
    const subject = 'Kode Verifikasi OTP — Apotek Santosa Farma';
    const html = `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e5e7eb; border-radius: 12px; background-color: #ffffff;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #059669; margin: 0;">Apotek Santosa Farma</h2>
          <p style="color: #6b7280; font-size: 14px; margin-top: 4px;">Kode Verifikasi Akun</p>
        </div>
        <p style="color: #374151; font-size: 15px;">Halo,</p>
        <p style="color: #374151; font-size: 15px;">Gunakan kode OTP berikut untuk menyelesaikan proses verifikasi Anda:</p>
        <div style="background-color: #f0fdf4; border: 2px dashed #059669; border-radius: 8px; padding: 16px; text-align: center; margin: 24px 0;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #059669;">${code}</span>
        </div>
        <p style="color: #6b7280; font-size: 13px;">Kode ini hanya berlaku selama <strong>5 menit</strong>. Jangan pernah memberikan kode ini kepada siapa pun, termasuk staf apotek.</p>
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
        <p style="color: #9ca3af; font-size: 12px; text-align: center; margin: 0;">© ${new Date().getFullYear()} Apotek Santosa Farma. Layanan Farmasi & Kesehatan Terpercaya.</p>
      </div>
    `;
    return await sendEmail(target, subject, message, html);
  }
}

/**
 * Unified Password Reset Dispatcher (WhatsApp or Email)
 */
export async function sendPasswordResetNotification(
  customerName: string,
  target: string,
  type: 'phone' | 'email',
  resetUrl: string
): Promise<boolean> {
  const message = `Halo ${customerName}, Anda telah meminta reset password di Apotek Santosa Farma. Klik link berikut untuk mengatur password baru Anda: ${resetUrl} . Link berlaku selama 30 menit.`;

  if (type === 'phone') {
    return await sendWhatsApp(target, message);
  } else {
    const subject = 'Link Reset Password — Apotek Santosa Farma';
    const html = `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e5e7eb; border-radius: 12px; background-color: #ffffff;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #059669; margin: 0;">Apotek Santosa Farma</h2>
          <p style="color: #6b7280; font-size: 14px; margin-top: 4px;">Permintaan Reset Password</p>
        </div>
        <p style="color: #374151; font-size: 15px;">Halo <strong>${customerName}</strong>,</p>
        <p style="color: #374151; font-size: 15px;">Kami menerima permintaan untuk mereset kata sandi akun Apotek Santosa Farma Anda.</p>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${resetUrl}" style="background-color: #059669; color: #ffffff; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 15px; display: inline-block;">Atur Password Baru</a>
        </div>
        <p style="color: #6b7280; font-size: 13px;">Tautan ini hanya berlaku selama <strong>30 menit</strong>. Jika Anda tidak merasa meminta reset password, abaikan email ini dengan aman.</p>
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
        <p style="color: #9ca3af; font-size: 12px; text-align: center; margin: 0;">© ${new Date().getFullYear()} Apotek Santosa Farma.</p>
      </div>
    `;
    return await sendEmail(target, subject, message, html);
  }
}
