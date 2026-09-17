import nodemailer from 'nodemailer';
import { config } from '../config.js';

let transporter = null;

function getTransporter() {
  if (transporter) return transporter;
  if (!config.mail.host || !config.mail.user) return null;
  transporter = nodemailer.createTransport({
    host: config.mail.host,
    port: config.mail.port,
    secure: config.mail.secure,
    auth: { user: config.mail.user, pass: config.mail.pass },
  });
  return transporter;
}

// -------------------------------------------------------------------
// Тексты письма на трёх языках
// -------------------------------------------------------------------
const TEXTS = {
  ru: {
    subject: 'Код подтверждения NFT-Grader',
    title: 'Подтвердите почту',
    intro: 'Введите этот код в приложении, чтобы завершить регистрацию:',
    expires: 'Код действует 10 минут.',
    ignore: 'Если вы не создавали аккаунт, просто проигнорируйте это письмо.',
  },
  uk: {
    subject: 'Код підтвердження NFT-Grader',
    title: 'Підтвердьте пошту',
    intro: 'Введіть цей код у застосунку, щоб завершити реєстрацію:',
    expires: 'Код дійсний 10 хвилин.',
    ignore: 'Якщо ви не створювали акаунт, просто проігноруйте цей лист.',
  },
  en: {
    subject: 'Your NFT-Grader verification code',
    title: 'Verify your e-mail',
    intro: 'Enter this code in the app to finish signing up:',
    expires: 'The code is valid for 10 minutes.',
    ignore: 'If you did not create an account, you can ignore this e-mail.',
  },
};

function renderHtml(code, t) {
  // Инлайновые стили: почтовые клиенты вырезают <style> и внешний CSS.
  return `<!doctype html>
<html><body style="margin:0;padding:0;background:#0b0b0f;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0b0b0f;padding:40px 16px;">
    <tr><td align="center">
      <table width="100%" style="max-width:480px;background:#16161c;border:1px solid rgba(255,255,255,.08);border-radius:20px;overflow:hidden;">
        <tr><td style="padding:32px 32px 8px;text-align:center;">
          <div style="font-size:13px;letter-spacing:3px;color:#FFC107;font-weight:800;">NFT-GRADER</div>
          <h1 style="margin:16px 0 8px;font-size:22px;color:#fff;">${t.title}</h1>
          <p style="margin:0;color:#9CA3AF;font-size:14px;line-height:1.5;">${t.intro}</p>
        </td></tr>
        <tr><td style="padding:24px 32px;text-align:center;">
          <div style="display:inline-block;padding:16px 28px;background:rgba(255,193,7,.12);border:1px solid rgba(255,193,7,.45);border-radius:14px;">
            <span style="font-size:34px;font-weight:800;letter-spacing:10px;color:#FFC107;">${code}</span>
          </div>
          <p style="margin:16px 0 0;color:#6B7280;font-size:12px;">${t.expires}</p>
        </td></tr>
        <tr><td style="padding:0 32px 32px;text-align:center;">
          <p style="margin:0;color:#6B7280;font-size:12px;line-height:1.5;">${t.ignore}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}

/// Отправляет код подтверждения. В разработке, если SMTP не настроен,
/// просто печатает код в консоль — регистрацию можно тестировать без почты.
export async function sendVerificationCode(email, code, locale = 'ru') {
  const t = TEXTS[locale] || TEXTS.ru;
  const tx = getTransporter();

  if (!tx) {
    if (config.mail.devLog) {
      console.log(`\n📧 [DEV] Код для ${email}: ${code}\n`);
      return { dev: true };
    }
    throw new Error('smtp_not_configured');
  }

  await tx.sendMail({
    from: config.mail.from,
    to: email,
    subject: t.subject,
    text: `${t.intro}\n\n${code}\n\n${t.expires}`,
    html: renderHtml(code, t),
  });
  return { dev: false };
}
