"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onLocationUpdated = exports.onEventAdded = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
const groq_sdk_1 = require("groq-sdk");
const geofire = __importStar(require("geofire-common"));
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
const groq = new groq_sdk_1.Groq({
    apiKey: process.env.GROQ_API_KEY || "fallback",
});
/**
 * Trigger 1: When a new event is added
 * Logic: Find users matching the event category, ask Groq AI to generate a message, send Push Notification.
 */
exports.onEventAdded = functions.firestore.onDocumentCreated({ document: "events/{eventId}", secrets: ["GROQ_API_KEY"] }, async (event) => {
    var _a, _b;
    const snap = event.data;
    if (!snap)
        return;
    const eventData = snap.data();
    const category = eventData.category;
    console.log(`New event added: ${eventData.title} in category: ${category}`);
    // Find users who have this category in preferred_categories
    const usersSnapshot = await db.collection('users').get();
    const tokens = [];
    for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const prefs = userData.preferred_categories || [];
        if (prefs.includes(category)) {
            if (userData.fcm_token)
                tokens.push(userData.fcm_token);
            if (userData.fcm_tokens && Array.isArray(userData.fcm_tokens)) {
                tokens.push(...userData.fcm_tokens);
            }
        }
    }
    if (tokens.length === 0) {
        console.log("No users found matching this category with an FCM token.");
        return;
    }
    // Use Groq AI to generate a message
    let notificationBody = `A new ${category} event "${eventData.title}" has been added!`;
    try {
        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: 'user', content: `Write a very short, exciting push notification body (max 2 sentences) for a new sports event called "${eventData.title}", category: ${category}, location: ${eventData.location}.` }],
            model: 'llama-3.1-8b-instant',
        });
        if ((_b = (_a = chatCompletion.choices[0]) === null || _a === void 0 ? void 0 : _a.message) === null || _b === void 0 ? void 0 : _b.content) {
            notificationBody = chatCompletion.choices[0].message.content.replace(/"/g, '').trim();
        }
    }
    catch (e) {
        console.error("Groq AI Error:", e);
    }
    const uniqueTokens = [...new Set(tokens)];
    const payload = {
        notification: {
            title: "New Event Alert! 🔥",
            body: notificationBody,
        },
        tokens: uniqueTokens,
    };
    const response = await messaging.sendEachForMulticast(payload);
    console.log(`Successfully sent ${response.successCount} messages; failed ${response.failureCount}.`);
});
/**
 * Trigger 2: When a user's location is updated
 * Logic: Check nearby events, ask Groq AI to generate a message, send Push Notification.
 */
exports.onLocationUpdated = functions.firestore.onDocumentUpdated({ document: "users/{userId}", secrets: ["GROQ_API_KEY"] }, async (event) => {
    var _a, _b, _c, _d;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!after || !before)
        return;
    // Only trigger if location changed significantly (simplistic check)
    const latChanged = before.last_known_lat !== after.last_known_lat;
    const lngChanged = before.last_known_lng !== after.last_known_lng;
    if (!latChanged && !lngChanged) {
        return; // Location didn't change
    }
    if (!after.last_known_lat || !after.last_known_lng) {
        return; // Missing data
    }
    const tokens = [];
    if (after.fcm_token)
        tokens.push(after.fcm_token);
    if (after.fcm_tokens && Array.isArray(after.fcm_tokens)) {
        tokens.push(...after.fcm_tokens);
    }
    if (tokens.length === 0) {
        return; // Missing tokens
    }
    // Check if recently notified (throttle to 1 notification per 24 hours)
    const lastNotified = after.last_notified_at;
    if (lastNotified) {
        const lastNotifiedTime = lastNotified.toDate().getTime();
        const now = Date.now();
        if (now - lastNotifiedTime < 24 * 60 * 60 * 1000) {
            console.log("Throttled: User was already notified within the last 24 hours.");
            return;
        }
    }
    const userCenter = [after.last_known_lat, after.last_known_lng];
    const radiusInM = (after.preferred_radius_km || 50) * 1000;
    console.log(`User ${event.params.userId} location updated. Searching within ${radiusInM}m.`);
    // Find events near this location
    // Note: For a real production app, GeoFire/GeoHashes should be used to query efficiently.
    // Since we are not using GeoHashes in the database currently, we fetch active events and filter in memory.
    const eventsSnap = await db.collection('events').where('is_active', '==', true).get();
    const nearbyEvents = [];
    for (const doc of eventsSnap.docs) {
        const evData = doc.data();
        evData.id = doc.id;
        if (evData.lat && evData.lng) {
            const distanceInM = geofire.distanceBetween(userCenter, [evData.lat, evData.lng]) * 1000;
            if (distanceInM <= radiusInM) {
                nearbyEvents.push(evData);
            }
        }
    }
    if (nearbyEvents.length === 0) {
        console.log("No nearby events found for user.");
        return;
    }
    // Pick the closest or first event for the notification
    const suggestedEvent = nearbyEvents[0];
    let notificationBody = `There's a nearby event: ${suggestedEvent.title}!`;
    try {
        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: 'user', content: `Write a very short, exciting push notification body (max 2 sentences) telling a user that they are near a sports event called "${suggestedEvent.title}" at ${suggestedEvent.location}.` }],
            model: 'llama-3.1-8b-instant',
        });
        if ((_d = (_c = chatCompletion.choices[0]) === null || _c === void 0 ? void 0 : _c.message) === null || _d === void 0 ? void 0 : _d.content) {
            notificationBody = chatCompletion.choices[0].message.content.replace(/"/g, '').trim();
        }
    }
    catch (e) {
        console.error("Groq AI Error:", e);
    }
    const uniqueTokens = [...new Set(tokens)];
    const payload = {
        notification: {
            title: "Nearby Events Detected! 📍",
            body: notificationBody,
        },
        tokens: uniqueTokens,
    };
    try {
        await messaging.sendEachForMulticast(payload);
        console.log("Nearby notification sent successfully.");
        // Save to DB
        await db.collection('users').doc(event.params.userId).collection('notifications').add({
            title: payload.notification.title,
            body: payload.notification.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            type: "nearby_event",
            event_id: suggestedEvent.id || "",
            is_read: false
        });
        // Update last_notified_at
        await db.collection('users').doc(event.params.userId).update({
            last_notified_at: admin.firestore.FieldValue.serverTimestamp()
        });
    }
    catch (e) {
        console.error("Failed to send nearby notification:", e);
    }
});
//# sourceMappingURL=index.js.map