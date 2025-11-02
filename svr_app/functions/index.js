/**
 * Cloud Functions setup (v2 API) and Admin SDK initialization
 */
const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// Import notification functions
const notificationFunctions = require('./src/notifications');

// Global options for all functions
setGlobalOptions({ maxInstances: 10, region: "us-central1" });

// Export all functions
module.exports = {
  ...notificationFunctions,
  createUserWithRole: onCall(async (request) => {
    try {
      const caller = request.auth;
      if (!caller) {
        throw new HttpsError("unauthenticated", "Authentication required.");
      }

      const callerRole = caller.token?.role;
      if (callerRole !== "super_admin") {
        throw new HttpsError("permission-denied", "Only super admins can create users.");
      }

      const { email, password, role = "user" } = request.data || {};

      if (!email || typeof email !== "string") {
        throw new HttpsError("invalid-argument", "Field 'email' is required and must be a string.");
      }

      let userRecord;

      // Check if user already exists
      try {
        userRecord = await admin.auth().getUserByEmail(email);
        // User exists, update their role
        await admin.auth().setCustomUserClaims(userRecord.uid, { role });
        logger.info("User role updated", { uid: userRecord.uid, email, role });
      } catch (error) {
        // User doesn't exist, create new user
        if (!password || typeof password !== "string" || password.length < 6) {
          throw new HttpsError("invalid-argument", "Field 'password' is required, string, and at least 6 chars for new users.");
        }

        userRecord = await admin.auth().createUser({
          email,
          password,
          emailVerified: false,
          disabled: false,
        });

        // Attach custom claims
        await admin.auth().setCustomUserClaims(userRecord.uid, { role });
        logger.info("User created with role", { uid: userRecord.uid, email, role });
      }

      return { uid: userRecord.uid, email, role };
    } catch (err) {
      // Re-throw HttpsError as-is; wrap unknown errors
      if (err instanceof HttpsError) {
        throw err;
      }
      logger.error("Error creating/updating user with role", err);
      throw new HttpsError("internal", (err && err.message) || "Unknown error");
    }
  })
};
