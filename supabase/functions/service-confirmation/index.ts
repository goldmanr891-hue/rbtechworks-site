// Sends a "we got your request" email when a website service request is saved.
// Triggered by a Supabase database webhook on INSERT into public.services.
// It trusts nothing in the request body except the row id: the row is re-read with the
// service key, only Website rows with an email get a reply, and each row is emailed once.
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM = "RB Tech Works <support@rbtechworks.com>";

const esc = (s: string) =>
  s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

Deno.serve(async (req) => {
  let id: number | undefined;
  try {
    const body = await req.json();
    id = Number(body?.record?.id);
  } catch { /* fall through */ }
  if (!id) return new Response("no record id", { status: 400 });

  const { data: svc, error } = await supabase
    .from("services").select("id, name, email, service_type, source").eq("id", id).single();
  if (error || !svc) return new Response("not found", { status: 404 });
  if (svc.source !== "Website" || !svc.email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(svc.email)) {
    return new Response("skipped", { status: 200 });
  }

  const { count } = await supabase
    .from("service_events").select("id", { count: "exact", head: true })
    .eq("service_id", id).eq("kind", "email");
  if (count) return new Response("already sent", { status: 200 });

  const first = esc((svc.name || "").trim().split(/\s+/)[0] || "there");
  const text =
`Hi ${first},

Thanks for contacting RB Tech Works! We received your request (#${svc.id}) and will get back to you within one business day, usually sooner.

Hours: Monday–Friday 7AM–5PM, Saturday 7AM–12PM
Need us sooner? Call or text (248) 408-9718.

RB Tech Works · Holly, MI · rbtechworks.com`;
  const html = `<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.5;color:#15211d">
<p>Hi ${first},</p>
<p>Thanks for contacting <b>RB Tech Works</b>! We received your request <b>(#${svc.id})</b> and will get back to you within one business day, usually sooner.</p>
<p>Hours: Monday–Friday 7AM–5PM, Saturday 7AM–12PM<br>Need us sooner? Call or text <b>(248) 408-9718</b>.</p>
<p style="color:#56645f;font-size:13px">RB Tech Works · Holly, MI · <a href="https://rbtechworks.com" style="color:#1d6b4a">rbtechworks.com</a></p></div>`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: FROM,
      to: [svc.email],
      reply_to: "support@rbtechworks.com",
      subject: `We got your request – RB Tech Works (#${svc.id})`,
      text,
      html,
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    await supabase.from("service_events").insert({ service_id: id, kind: "note", message: `Confirmation email failed: ${detail.slice(0, 300)}` });
    return new Response("send failed", { status: 502 });
  }
  await supabase.from("service_events").insert({ service_id: id, kind: "email", message: `Confirmation email sent to ${svc.email}` });
  return new Response("sent", { status: 200 });
});
