# MASLIVE — Gestion complète commandes → Inbox vendeur + Push + Deep Link (1 fichier)

Ce document unique contient **tout** : Firestore structure, Cloud Function v2 (Node 20), règles Firestore, et Flutter (FCM token sync + réception push + boîte à messages + page détail commande + validation).

> ⚠️ Note “app fermée” :
- Android : les push “notification” s’affichent même app fermée.
- iOS : idem si l’utilisateur a autorisé les notifications. Les “data-only” peuvent être limités en arrière-plan ; on envoie donc **notification + data**.

---

## 0) Hypothèses de données Firestore

### Produits
`products/{productId}`
- `ownerId` (uid vendeur / admin groupe)
- `title`
- `priceCents`
- `...`

### Commandes
`orders/{orderId}`
- `buyerId`
- `status`: `"pending" | "validated" | "rejected"`
- `createdAt` (serverTimestamp)
- `items`: array d’objets :
  - `productId`
  - `title`
  - `priceCents`
  - `qty`
  - `sellerId`  ✅ obligatoire (uid du vendeur/owner)
- `sellerIds`: array unique (optionnel, utile)

### Boîte à messages vendeur
`users/{uid}/inbox/{messageId}`
- `type`: `"order"`
- `title`
- `body`
- `orderId`
- `deepLink`: `maslive://orders/{orderId}`
- `createdAt`
- `read`: false
- `actionLabel`: `"Consulter la commande"`

### Tokens FCM par device
`users/{uid}/devices/{deviceId}`
- `token`
- `platform`: `"ios" | "android" | "web"`
- `updatedAt`

---

## 1) Cloud Functions v2 (Node 20) — index.ts (copier-coller)

📌 Fichier : `functions/src/index.ts`

```ts
import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

admin.initializeApp();

type OrderItem = {
  productId: string;
  title?: string;
  priceCents?: number;
  qty?: number;
  sellerId: string;
};

type OrderDoc = {
  buyerId: string;
  status?: string;
  createdAt?: any;
  items: OrderItem[];
  sellerIds?: string[];
};

function unique(arr: string[]): string[] {
  return Array.from(new Set(arr.filter(Boolean)));
}

function deepLinkForOrder(orderId: string) {
  return `maslive://orders/${orderId}`;
}

async function writeInboxMessage(params: {
  sellerId: string;
  orderId: string;
  buyerId?: string;
  nbItems?: number;
}) {
  const { sellerId, orderId, buyerId, nbItems } = params;

  const title = "Nouvelle commande";
  const body = `Une commande est en attente de validation.${nbItems ? ` (${nbItems} article(s))` : ""}`;

  const message = {
    type: "order",
    title,
    body,
    orderId,
    deepLink: deepLinkForOrder(orderId),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
    actionLabel: "Consulter la commande",
    meta: {
      buyerId: buyerId ?? "",
    },
  };

  await admin.firestore()
    .collection("users")
    .doc(sellerId)
    .collection("inbox")
    .add(message);
}

async function getFcmTokensForUser(uid: string): Promise<string[]> {
  const snap = await admin.firestore()
    .collection("users")
    .doc(uid)
    .collection("devices")
    .get();

  const tokens: string[] = [];
  snap.forEach((d) => {
    const t = d.get("token");
    if (typeof t === "string" && t.length > 10) tokens.push(t);
  });

  return unique(tokens);
}

async function cleanupInvalidTokens(uid: string, invalidTokens: Set<string>) {
  if (invalidTokens.size === 0) return;

  const devicesSnap = await admin.firestore()
    .collection("users")
    .doc(uid)
    .collection("devices")
    .get();

  const batch = admin.firestore().batch();
  devicesSnap.forEach((doc) => {
    const token = doc.get("token");
    if (typeof token === "string" && invalidTokens.has(token)) {
      batch.delete(doc.ref);
    }
  });

  await batch.commit();
}

async function sendPushToSeller(params: {
  sellerId: string;
  orderId: string;
  nbItems?: number;
}) {
  const { sellerId, orderId, nbItems } = params;

  const tokens = await getFcmTokensForUser(sellerId);
  if (tokens.length === 0) {
    logger.info(`No FCM tokens for seller ${sellerId}`);
    return;
  }

  const title = "Nouvelle commande";
  const body = `Commande à valider${nbItems ? ` (${nbItems} article(s))` : ""}`;

  // On envoie NOTIFICATION + DATA (meilleur support en arrière-plan)
  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title, body },
    data: {
      type: "order",
      orderId,
      deepLink: deepLinkForOrder(orderId),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "orders",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const resp = await admin.messaging().sendEachForMulticast(message);

  const invalid = new Set<string>();
  resp.responses.forEach((r, idx) => {
    if (!r.success) {
      const code = (r.error as any)?.code || "";
      // tokens invalides fréquents
      if (
        code.includes("registration-token-not-registered") ||
        code.includes("invalid-registration-token") ||
        code.includes("messaging/invalid-argument") ||
        code.includes("messaging/registration-token-not-registered")
      ) {
        invalid.add(tokens[idx]);
      }
      logger.warn(`Push failed seller=${sellerId} tokenIndex=${idx} code=${code}`, r.error);
    }
  });

  await cleanupInvalidTokens(sellerId, invalid);
}

export const notifySellersOnOrderCreate = onDocumentCreated(
  {
    document: "orders/{orderId}",
    region: "us-east1",
  },
  async (event) => {
    const orderId = event.params.orderId;
    const snap = event.data;
    if (!snap) return;

    const order = snap.data() as OrderDoc;

    const items = Array.isArray(order.items) ? order.items : [];
    const sellerIdsFromItems = items.map((it) => it?.sellerId).filter(Boolean) as string[];
    const sellerIds = unique([
      ...(Array.isArray(order.sellerIds) ? order.sellerIds : []),
      ...sellerIdsFromItems,
    ]);

    if (sellerIds.length === 0) {
      logger.warn(`Order ${orderId} has no sellers`);
      return;
    }

    const nbItems = items.length;

    // Inbox + Push pour chaque vendeur
    await Promise.all(
      sellerIds.map(async (sellerId) => {
        await writeInboxMessage({
          sellerId,
          orderId,
          buyerId: order.buyerId,
          nbItems,
        });
        await sendPushToSeller({
          sellerId,
          orderId,
          nbItems,
        });
      })
    );

    logger.info(`Notified sellers for order ${orderId}`, { sellerIds });
  }
);
```
