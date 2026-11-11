// Small shared UI helpers: toasts and the badge celebration.

export function toast(message, { tone = "info", sentry = true, ms = 4200 } = {}) {
  const host = document.getElementById("toasts")
  if (!host || !message) return
  const el = document.createElement("div")
  el.className = `toast toast-${tone}`
  el.setAttribute("role", "status")
  if (sentry) {
    const img = document.createElement("img")
    img.src = document.body.dataset.eggsSentryValue || ""
    img.alt = ""
    img.className = "toast-sentry"
    el.append(img)
  }
  const text = document.createElement("span")
  text.textContent = message
  el.append(text)
  host.append(el)
  requestAnimationFrame(() => el.classList.add("is-in"))
  setTimeout(() => { el.classList.remove("is-in"); setTimeout(() => el.remove(), 400) }, ms)
}

export function celebrate(badges) {
  if (!badges || !badges.length) return
  document.querySelector(".celebration")?.remove()
  const wrap = document.createElement("div")
  wrap.className = "celebration"
  wrap.setAttribute("role", "dialog")
  wrap.setAttribute("aria-modal", "true")
  wrap.setAttribute("aria-labelledby", "celebration-title")
  wrap.dataset.controller = "celebration"
  const card = document.createElement("div")
  card.className = "celebration-card"
  const sentry = document.createElement("img")
  sentry.src = document.body.dataset.eggsSentryValue || ""
  sentry.alt = "Sentry, cheering"
  sentry.className = "celebration-sentry"
  sentry.width = 120; sentry.height = 150
  const eyebrow = document.createElement("p")
  eyebrow.className = "eyebrow varsity-small"
  eyebrow.textContent = badges.length > 1 ? "Badges earned" : "Badge earned"
  card.append(sentry, eyebrow)
  badges.forEach((b, i) => {
    const box = document.createElement("div")
    box.className = "celebration-badge"
    const img = document.createElement("img")
    img.src = b.image; img.alt = b.name; img.width = 96; img.height = 108; img.className = "badge-img"
    const h = document.createElement("h2")
    if (i === 0) h.id = "celebration-title"
    h.textContent = b.name
    const p = document.createElement("p")
    p.textContent = b.description
    box.append(img, h, p)
    card.append(box)
  })
  const btn = document.createElement("button")
  btn.type = "button"
  btn.className = "btn btn-primary"
  btn.dataset.action = "celebration#close"
  btn.textContent = "Back to work"
  card.append(btn)
  wrap.append(card)
  document.body.append(wrap)
  btn.focus()
}

export function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || ""
}

export async function postJSON(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": csrfToken() },
    body: JSON.stringify(body),
    credentials: "same-origin"
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  return res.json()
}

export const pick = list => Array.isArray(list) ? list[Math.floor(Math.random() * list.length)] : list
