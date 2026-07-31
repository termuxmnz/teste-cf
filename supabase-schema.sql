import crypto from "node:crypto";
import { getStore } from "@netlify/blobs";
import seed from "./seed.mjs";

const STORE_NAME = "code-forge-pedidos";
const DB_KEY = "database";
const IS_PROD = process.env.CONTEXT === "production" || process.env.NODE_ENV === "production";
const ADMIN_EMAIL = String(process.env.ADMIN_EMAIL || "admin@codeforge.test").trim().toLowerCase();
const ADMIN_PASSWORD = String(process.env.ADMIN_PASSWORD || "");
const SESSION_SECRET = String(process.env.SESSION_SECRET || (IS_PROD ? "" : "code-forge-local-session-secret-change-me"));
const buckets = new Map();

function json(status, payload, extraHeaders = {}) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "x-frame-options": "DENY",
      "referrer-policy": "strict-origin-when-cross-origin",
      "permissions-policy": "camera=(), microphone=(), geolocation=()",
      ...extraHeaders,
    },
  });
}

function safeText(value, max = 300) {
  return String(value ?? "").trim().replace(/\s+/g, " ").slice(0, max);
}
function digits(value, max = 15) {
  return String(value ?? "").replace(/\D/g, "").slice(0, max);
}
function normalizeEmail(value) {
  return safeText(value, 180).toLowerCase();
}
function money(cents) {
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(cents / 100);
}
function clone(value) {
  return structuredClone(value);
}
function hashPassword(password, salt = crypto.randomBytes(16).toString("hex")) {
  return {
    salt,
    hash: crypto.pbkdf2Sync(password, salt, 120000, 32, "sha256").toString("hex"),
  };
}
function verifyPassword(password, salt, hash) {
  try {
    const got = Buffer.from(hashPassword(password, salt).hash, "hex");
    const want = Buffer.from(hash, "hex");
    return got.length === want.length && crypto.timingSafeEqual(got, want);
  } catch {
    return false;
  }
}
function randomToken() {
  return crypto.randomBytes(24).toString("hex");
}
function encodeBase64Url(value) {
  return Buffer.from(value).toString("base64url");
}
function signSession(payload) {
  if (!SESSION_SECRET) throw Object.assign(new Error("SESSION_SECRET não configurado na Netlify."), { status: 503 });
  const body = encodeBase64Url(JSON.stringify(payload));
  const signature = crypto.createHmac("sha256", SESSION_SECRET).update(body).digest("base64url");
  return `${body}.${signature}`;
}
function verifySession(token, expectedType) {
  if (!token || !SESSION_SECRET) return null;
  const [body, signature] = String(token).split(".");
  if (!body || !signature) return null;
  const expected = crypto.createHmac("sha256", SESSION_SECRET).update(body).digest("base64url");
  const a = Buffer.from(signature);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const payload = JSON.parse(Buffer.from(body, "base64url").toString("utf8"));
    if (payload.type !== expectedType || !payload.exp || payload.exp < Date.now()) return null;
    return payload;
  } catch {
    return null;
  }
}
function parseCookies(request) {
  const out = {};
  const raw = request.headers.get("cookie") || "";
  raw.split(";").forEach((part) => {
    const index = part.indexOf("=");
    if (index > -1) out[part.slice(0, index).trim()] = decodeURIComponent(part.slice(index + 1).trim());
  });
  return out;
}
function sessionCookie(name, value, maxAge) {
  const pieces = [`${name}=${encodeURIComponent(value)}`, "Path=/", "HttpOnly", "SameSite=Strict", `Max-Age=${maxAge}`];
  if (IS_PROD) pieces.push("Secure");
  return pieces.join("; ");
}
function customerSession(request) {
  return verifySession(parseCookies(request).cf_session, "customer");
}
function adminSession(request) {
  return verifySession(parseCookies(request).cf_admin, "admin");
}
function requireAdmin(request, csrf = false) {
  const session = adminSession(request);
  if (!session) throw Object.assign(new Error("Faça login no painel."), { status: 401 });
  if (csrf && request.headers.get("x-csrf-token") !== session.csrf) {
    throw Object.assign(new Error("Token de segurança inválido."), { status: 403 });
  }
  return session;
}
function clientIp(request) {
  return (request.headers.get("x-nf-client-connection-ip") || request.headers.get("x-forwarded-for") || "unknown").split(",")[0].trim();
}
function rateLimit(request, key, limit, windowMs) {
  const mapKey = `${key}:${clientIp(request)}`;
  const now = Date.now();
  let bucket = buckets.get(mapKey);
  if (!bucket || bucket.until < now) bucket = { count: 0, until: now + windowMs };
  bucket.count += 1;
  buckets.set(mapKey, bucket);
  if (bucket.count > limit) throw Object.assign(new Error("Muitas tentativas. Aguarde e tente novamente."), { status: 429 });
}
async function readBody(request, max = 1_000_000) {
  const text = await request.text();
  if (Buffer.byteLength(text) > max) throw Object.assign(new Error("Corpo muito grande."), { status: 413 });
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw Object.assign(new Error("JSON inválido."), { status: 400 });
  }
}

function blobsStore() {
  return getStore({ name: STORE_NAME, consistency: "strong" });
}
async function readDatabase() {
  const store = blobsStore();
  let entry = await store.getWithMetadata(DB_KEY, { type: "json", consistency: "strong" });
  if (entry) return { store, db: entry.data, etag: entry.etag };

  const created = await store.setJSON(DB_KEY, clone(seed), { onlyIfNew: true });
  if (created.modified) return { store, db: clone(seed), etag: created.etag };

  entry = await store.getWithMetadata(DB_KEY, { type: "json", consistency: "strong" });
  if (!entry) throw Object.assign(new Error("Não foi possível iniciar o banco da demonstração."), { status: 503 });
  return { store, db: entry.data, etag: entry.etag };
}
async function mutateDatabase(mutator, retries = 7) {
  for (let attempt = 0; attempt < retries; attempt += 1) {
    const { store, db: current, etag } = await readDatabase();
    const db = clone(current);
    const mutation = await mutator(db);
    if (mutation?.changed === false) return mutation.value;

    const written = await store.setJSON(DB_KEY, db, { onlyIfMatch: etag });
    if (written.modified) return mutation?.value;
    await new Promise((resolve) => setTimeout(resolve, 25 + attempt * 35));
  }
  throw Object.assign(new Error("O estoque mudou ao mesmo tempo. Tente finalizar novamente."), { status: 409 });
}

function zonedParts(timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(new Date());
  const mapped = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  const days = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  return { day: days[mapped.weekday], minutes: Number(mapped.hour) * 60 + Number(mapped.minute) };
}
function hhmm(value) {
  const [hours, minutes] = String(value).split(":").map(Number);
  return hours * 60 + minutes;
}
function storeStatus(db, storeId) {
  const store = db.stores[storeId];
  if (!store) return { open: false, reason: "Operação inválida" };
  if (store.statusMode === "open") return { open: true, reason: "Aberto manualmente para demonstração" };
  if (store.statusMode === "closed") return { open: false, reason: "Fechado manualmente" };
  const now = zonedParts(db.settings.timezone);
  const day = store.schedule[String(now.day)];
  if (!day?.enabled) return { open: false, reason: "Fechado hoje" };
  const open = now.minutes >= hhmm(day.open) && now.minutes <= hhmm(day.close);
  return { open, reason: open ? `Aberto até ${day.close}` : `Horário: ${day.open} às ${day.close}` };
}
function publicProduct(product) {
  return { ...product, optionGroups: product.optionGroups || [], available: Boolean(product.active && product.stock > 0) };
}
function catalog(db, storeId) {
  const id = db.stores[storeId] ? storeId : "restaurant";
  const products = db.products.filter((product) => product.store === id).map(publicProduct);
  return {
    store: id,
    storeInfo: db.stores[id],
    status: storeStatus(db, id),
    products,
    categories: [...new Set(products.map((product) => product.category))],
    settings: {
      businessName: db.settings.businessName,
      deliveryFee: db.settings.deliveryFee,
      freeDeliveryThreshold: db.settings.freeDeliveryThreshold,
      whatsapp: db.settings.whatsapp,
    },
  };
}
function findProduct(db, id) {
  return db.products.find((product) => product.id === id);
}
function validateSelections(product, selections = {}) {
  const normalized = {};
  let extras = 0;
  const display = [];
  for (const group of product.optionGroups || []) {
    const raw = Array.isArray(selections[group.id]) ? selections[group.id] : [];
    const ids = [...new Set(raw.map(String))];
    const valid = ids.filter((id) => group.options.some((option) => option.id === id));
    if (valid.length < group.min || valid.length > group.max) {
      throw Object.assign(new Error(`Revise: ${group.title}.`), { status: 400 });
    }
    const chosen = group.options.filter((option) => valid.includes(option.id));
    if (chosen.some((option) => option.exclusive) && chosen.length > 1) {
      throw Object.assign(new Error(`A opção exclusiva de “${group.title}” não pode ser combinada.`), { status: 400 });
    }
    normalized[group.id] = valid;
    for (const option of chosen) {
      extras += option.price;
      display.push({ group: group.title, label: option.label, price: option.price });
    }
  }
  return { normalized, extras, display };
}
function generateCode(db) {
  const date = new Date();
  const stamp = `${String(date.getDate()).padStart(2, "0")}${String(date.getMonth() + 1).padStart(2, "0")}`;
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const code = `CF-${stamp}-${crypto.randomInt(1000, 10000)}`;
    if (!db.orders.some((order) => order.code === code)) return code;
  }
  return `CF-${stamp}-${Date.now().toString().slice(-6)}`;
}
function whatsappText(order) {
  const lines = [
    `*NOVO PEDIDO ${order.code}*`,
    "",
    `Cliente: ${order.customer.name}`,
    `Telefone: ${order.customer.phone}`,
    `Modalidade: ${order.fulfillment === "delivery" ? "Entrega" : "Retirada"}`,
  ];
  if (order.fulfillment === "delivery") lines.push(`Endereço: ${order.customer.address}`);
  lines.push("");
  order.items.forEach((item, index) => {
    lines.push(`*${index + 1}. ${item.quantity}x ${item.name}* — ${money(item.total)}`);
    item.options.forEach((option) => lines.push(`• ${option.label}${option.price ? ` (+${money(option.price * item.quantity)})` : ""}`));
    if (item.note) lines.push(`Obs.: ${item.note}`);
    lines.push("");
  });
  lines.push(`Subtotal: ${money(order.subtotal)}`);
  if (order.deliveryFee) lines.push(`Taxa de entrega: ${money(order.deliveryFee)}`);
  lines.push(
    `*TOTAL CONFIRMADO: ${money(order.total)}*`,
    `Pagamento: ${order.paymentMethod}`,
    "",
    `O valor oficial está salvo no painel pelo código ${order.code}.`,
  );
  return lines.join("\n");
}
function sanitizeOrder(order) {
  return { ...order, customer: { name: order.customer.name, phone: order.customer.phone, address: order.customer.address || "" } };
}
function statusLabel(status) {
  return ({
    aguardando_whatsapp: "Aguardando WhatsApp",
    recebido: "Recebido",
    confirmado: "Confirmado",
    em_preparo: "Em preparo",
    pronto: "Pronto",
    saiu_para_entrega: "Saiu para entrega",
    entregue: "Entregue",
    cancelado: "Cancelado",
  })[status] || status;
}

async function createOrder(request) {
  rateLimit(request, "order", 20, 10 * 60_000);
  const body = await readBody(request);
  const idempotencyKey = safeText(body.idempotencyKey, 100);
  if (!idempotencyKey) throw Object.assign(new Error("Chave de finalização ausente."), { status: 400 });

  const result = await mutateDatabase((db) => {
    if (db.idempotency[idempotencyKey]) {
      const existing = db.orders.find((order) => order.id === db.idempotency[idempotencyKey]);
      return { changed: false, value: { duplicate: true, order: sanitizeOrder(existing), whatsappUrl: existing.whatsappUrl } };
    }

    const store = body.store;
    if (!db.stores[store]) throw Object.assign(new Error("Operação inválida."), { status: 400 });
    const status = storeStatus(db, store);
    if (!status.open) throw Object.assign(new Error(`A operação está fechada. ${status.reason}`), { status: 409 });

    const rawItems = Array.isArray(body.items) ? body.items : [];
    if (!rawItems.length) throw Object.assign(new Error("Carrinho vazio."), { status: 400 });
    if (rawItems.length > 30) throw Object.assign(new Error("Muitos itens no pedido."), { status: 400 });

    const customerData = {
      name: safeText(body.customer?.name, 80),
      phone: digits(body.customer?.phone),
      address: safeText(body.customer?.address, 180),
    };
    if (customerData.name.length < 2 || customerData.phone.length < 10) {
      throw Object.assign(new Error("Informe nome e telefone válidos."), { status: 400 });
    }

    const fulfillment = body.fulfillment === "delivery" ? "delivery" : "pickup";
    if (fulfillment === "delivery" && customerData.address.length < 8) {
      throw Object.assign(new Error("Informe o endereço de entrega."), { status: 400 });
    }

    const built = [];
    let subtotal = 0;
    for (const raw of rawItems) {
      const product = findProduct(db, raw.productId);
      if (!product || product.store !== store || !product.active) {
        throw Object.assign(new Error("Um produto não está mais disponível."), { status: 409 });
      }
      const quantity = Math.max(1, Math.min(20, Number(raw.quantity) || 1));
      if (product.stock < quantity) {
        throw Object.assign(new Error(`${product.name}: restam apenas ${product.stock} unidade(s).`), { status: 409 });
      }
      const selections = validateSelections(product, raw.selections || {});
      const total = (product.price + selections.extras) * quantity;
      subtotal += total;
      built.push({
        productId: product.id,
        name: product.name,
        quantity,
        unitPrice: product.price,
        unitExtras: selections.extras,
        total,
        selections: selections.normalized,
        options: selections.display,
        note: safeText(raw.note, 140),
        image: product.image,
      });
    }

    const deliveryFee = fulfillment === "delivery" && subtotal < db.settings.freeDeliveryThreshold ? db.settings.deliveryFee : 0;
    const customer = customerSession(request);
    const now = new Date().toISOString();
    const order = {
      id: crypto.randomUUID(),
      code: generateCode(db),
      store,
      createdAt: now,
      updatedAt: now,
      status: "aguardando_whatsapp",
      items: built,
      subtotal,
      deliveryFee,
      total: subtotal + deliveryFee,
      fulfillment,
      paymentMethod: safeText(body.paymentMethod || "Combinar pelo WhatsApp", 60),
      customer: customerData,
      customerId: customer?.id || null,
      statusHistory: [{ status: "aguardando_whatsapp", at: now }],
      idempotencyKey,
    };
    order.whatsappUrl = `https://wa.me/${db.settings.whatsapp}?text=${encodeURIComponent(whatsappText(order))}`;

    for (const item of built) {
      const product = findProduct(db, item.productId);
      product.stock -= item.quantity;
    }
    db.orders.unshift(order);
    db.idempotency[idempotencyKey] = order.id;
    return { changed: true, value: { duplicate: false, order: sanitizeOrder(order), whatsappUrl: order.whatsappUrl } };
  });

  return json(result.duplicate ? 200 : 201, { ok: true, ...result });
}

async function route(request) {
  const url = new URL(request.url);
  let path = url.pathname.replace(/^\/\.netlify\/functions\/api/, "/api");
  if (!path.startsWith("/api")) path = `/api${path.startsWith("/") ? "" : "/"}${path}`;
  const method = request.method.toUpperCase();

  if (method === "GET" && path === "/api/catalog") {
    const { db } = await readDatabase();
    return json(200, catalog(db, url.searchParams.get("store") || "restaurant"));
  }

  if (method === "GET" && path === "/api/auth/me") {
    const session = customerSession(request);
    if (!session) return json(200, { authenticated: false });
    const { db } = await readDatabase();
    const customer = db.customers.find((item) => item.id === session.id);
    return json(200, {
      authenticated: Boolean(customer),
      customer: customer ? { id: customer.id, name: customer.name, email: customer.email, phone: customer.phone } : null,
    });
  }

  if (method === "POST" && path === "/api/auth/register") {
    rateLimit(request, "register", 10, 15 * 60_000);
    const body = await readBody(request);
    const name = safeText(body.name, 80);
    const email = normalizeEmail(body.email);
    const phone = digits(body.phone);
    const password = String(body.password || "");
    if (name.length < 2 || !email.includes("@") || phone.length < 10 || password.length < 8) {
      throw Object.assign(new Error("Preencha os dados e use uma senha com pelo menos 8 caracteres."), { status: 400 });
    }
    const customer = await mutateDatabase((db) => {
      if (db.customers.some((item) => item.email === email)) throw Object.assign(new Error("E-mail já cadastrado."), { status: 409 });
      const passwordData = hashPassword(password);
      const created = {
        id: crypto.randomUUID(), name, email, phone,
        passwordHash: passwordData.hash,
        passwordSalt: passwordData.salt,
        createdAt: new Date().toISOString(),
      };
      db.customers.push(created);
      return { changed: true, value: created };
    });
    const token = signSession({ type: "customer", id: customer.id, exp: Date.now() + 72 * 3600_000 });
    return json(201, { ok: true, customer: { id: customer.id, name, email, phone } }, {
      "set-cookie": sessionCookie("cf_session", token, 72 * 3600),
    });
  }

  if (method === "POST" && path === "/api/auth/login") {
    rateLimit(request, "login", 15, 15 * 60_000);
    const body = await readBody(request);
    const { db } = await readDatabase();
    const customer = db.customers.find((item) => item.email === normalizeEmail(body.email));
    if (!customer || !verifyPassword(String(body.password || ""), customer.passwordSalt, customer.passwordHash)) {
      throw Object.assign(new Error("E-mail ou senha inválidos."), { status: 401 });
    }
    const token = signSession({ type: "customer", id: customer.id, exp: Date.now() + 72 * 3600_000 });
    return json(200, { ok: true, customer: { id: customer.id, name: customer.name, email: customer.email, phone: customer.phone } }, {
      "set-cookie": sessionCookie("cf_session", token, 72 * 3600),
    });
  }

  if (method === "POST" && path === "/api/auth/logout") {
    return json(200, { ok: true }, { "set-cookie": sessionCookie("cf_session", "", 0) });
  }

  if (method === "GET" && path === "/api/my-orders") {
    const session = customerSession(request);
    if (!session) return json(401, { error: "Faça login." });
    const { db } = await readDatabase();
    return json(200, { orders: db.orders.filter((order) => order.customerId === session.id).map(sanitizeOrder) });
  }

  if (method === "POST" && path === "/api/orders") return createOrder(request);

  const trackingMatch = path.match(/^\/api\/orders\/([^/]+)$/);
  if (method === "GET" && trackingMatch) {
    const code = decodeURIComponent(trackingMatch[1]).toUpperCase();
    const phone = digits(url.searchParams.get("phone"));
    const { db } = await readDatabase();
    const order = db.orders.find((item) => item.code.toUpperCase() === code);
    if (!order || !phone || !order.customer.phone.endsWith(phone.slice(-8))) {
      return json(404, { error: "Pedido não encontrado. Confira código e telefone." });
    }
    return json(200, { order: sanitizeOrder(order), statusLabel: statusLabel(order.status) });
  }

  if (method === "POST" && path === "/api/admin/login") {
    rateLimit(request, "admin-login", 10, 15 * 60_000);
    if (!ADMIN_PASSWORD || !SESSION_SECRET) {
      throw Object.assign(new Error("Configure ADMIN_PASSWORD e SESSION_SECRET na Netlify."), { status: 503 });
    }
    const body = await readBody(request);
    if (normalizeEmail(body.email) !== ADMIN_EMAIL || String(body.password || "") !== ADMIN_PASSWORD) {
      throw Object.assign(new Error("Credenciais inválidas."), { status: 401 });
    }
    const csrf = randomToken();
    const token = signSession({ type: "admin", email: ADMIN_EMAIL, csrf, exp: Date.now() + 8 * 3600_000 });
    return json(200, { ok: true, csrf }, { "set-cookie": sessionCookie("cf_admin", token, 8 * 3600) });
  }

  if (method === "POST" && path === "/api/admin/logout") {
    return json(200, { ok: true }, { "set-cookie": sessionCookie("cf_admin", "", 0) });
  }

  if (method === "GET" && path === "/api/admin/session") {
    const session = adminSession(request);
    return json(200, session ? { authenticated: true, email: session.email, csrf: session.csrf } : { authenticated: false });
  }

  if (method === "GET" && path === "/api/admin/dashboard") {
    requireAdmin(request);
    const { db } = await readDatabase();
    const revenue = db.orders.filter((order) => order.status !== "cancelado").reduce((total, order) => total + order.total, 0);
    return json(200, {
      stores: db.stores,
      products: db.products,
      orders: db.orders.map(sanitizeOrder),
      stats: {
        orders: db.orders.length,
        revenue,
        lowStock: db.products.filter((product) => product.stock <= 1).length,
        activeProducts: db.products.filter((product) => product.active).length,
      },
      statuses: db.settings.orderStatuses,
    });
  }

  const orderStatusMatch = path.match(/^\/api\/admin\/orders\/([^/]+)\/status$/);
  if (method === "PATCH" && orderStatusMatch) {
    requireAdmin(request, true);
    const body = await readBody(request);
    const order = await mutateDatabase((db) => {
      const current = db.orders.find((item) => item.id === orderStatusMatch[1]);
      if (!current) throw Object.assign(new Error("Pedido não encontrado."), { status: 404 });
      if (!db.settings.orderStatuses.includes(body.status)) throw Object.assign(new Error("Status inválido."), { status: 400 });
      if (current.status === "cancelado" && body.status !== "cancelado") {
        throw Object.assign(new Error("Um pedido cancelado não pode ser reaberto nesta demonstração."), { status: 409 });
      }
      if (body.status === "cancelado" && current.status !== "cancelado") {
        for (const item of current.items) {
          const product = findProduct(db, item.productId);
          if (product) product.stock += item.quantity;
        }
      }
      current.status = body.status;
      current.updatedAt = new Date().toISOString();
      current.statusHistory.push({ status: body.status, at: current.updatedAt });
      return { changed: true, value: current };
    });
    return json(200, { ok: true, order: sanitizeOrder(order) });
  }

  const productMatch = path.match(/^\/api\/admin\/products\/([^/]+)$/);
  if (method === "PATCH" && productMatch) {
    requireAdmin(request, true);
    const body = await readBody(request);
    const product = await mutateDatabase((db) => {
      const current = findProduct(db, productMatch[1]);
      if (!current) throw Object.assign(new Error("Produto não encontrado."), { status: 404 });
      if (body.name !== undefined) current.name = safeText(body.name, 120);
      if (body.description !== undefined) current.description = safeText(body.description, 500);
      if (body.price !== undefined) current.price = Math.max(0, Math.round(Number(body.price) * 100));
      if (body.oldPrice !== undefined) current.oldPrice = body.oldPrice === "" || body.oldPrice === null ? null : Math.max(0, Math.round(Number(body.oldPrice) * 100));
      if (body.stock !== undefined) current.stock = Math.max(0, Math.min(999, Math.floor(Number(body.stock) || 0)));
      if (body.active !== undefined) current.active = Boolean(body.active);
      return { changed: true, value: current };
    });
    return json(200, { ok: true, product });
  }

  const storeMatch = path.match(/^\/api\/admin\/stores\/(restaurant|snacks)$/);
  if (method === "PATCH" && storeMatch) {
    requireAdmin(request, true);
    const body = await readBody(request);
    if (!["open", "closed", "auto"].includes(body.statusMode)) throw Object.assign(new Error("Modo inválido."), { status: 400 });
    const store = await mutateDatabase((db) => {
      db.stores[storeMatch[1]].statusMode = body.statusMode;
      return { changed: true, value: db.stores[storeMatch[1]] };
    });
    const { db } = await readDatabase();
    return json(200, { ok: true, store, status: storeStatus(db, storeMatch[1]) });
  }

  if (method === "POST" && path === "/api/admin/reset") {
    requireAdmin(request, true);
    await mutateDatabase((db) => {
      Object.keys(db).forEach((key) => delete db[key]);
      Object.assign(db, clone(seed));
      return { changed: true, value: true };
    });
    return json(200, { ok: true });
  }

  return json(404, { error: "Rota não encontrada." });
}

export default async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204 });
  try {
    return await route(request);
  } catch (error) {
    console.error(error);
    const status = Number(error?.status || 500);
    return json(status, { error: status >= 500 && !error?.status ? "Erro interno do servidor." : error.message });
  }
};
