const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Send notifications based on type and target users
exports.sendNotification = functions.firestore
    .document('notification_queue/{notificationId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const { notificationId, title, message, type, targetUsers } = data;

        try {
            let tokens = [];

            // Get target tokens based on notification type
            if (type === 'Specific Users' && targetUsers) {
                // Get tokens for specific users
                const userDocs = await admin.firestore()
                    .collection('users')
                    .where('id', 'in', targetUsers)
                    .get();
                
                tokens = userDocs.docs
                    .map(doc => doc.data().fcmToken)
                    .filter(token => token);
            } else if (type === 'Active Users') {
                // Get tokens for active users
                const userDocs = await admin.firestore()
                    .collection('users')
                    .where('status', '==', 'active')
                    .get();
                
                tokens = userDocs.docs
                    .map(doc => doc.data().fcmToken)
                    .filter(token => token);
            } else {
                // Get all user tokens
                const userDocs = await admin.firestore()
                    .collection('users')
                    .get();
                
                tokens = userDocs.docs
                    .map(doc => doc.data().fcmToken)
                    .filter(token => token);
            }

            // Update notification status
            await admin.firestore()
                .collection('notifications')
                .doc(notificationId)
                .update({
                    status: 'sending',
                    recipientCount: tokens.length
                });

            // Send notifications in batches of 500
            const batchSize = 500;
            const batches = [];
            
            for (let i = 0; i < tokens.length; i += batchSize) {
                const batch = tokens.slice(i, i + batchSize);
                
                if (batch.length > 0) {
                    const messages = batch.map(token => ({
                        notification: { title, body: message },
                        token
                    }));

                    batches.push(
                        admin.messaging().sendAll(messages)
                            .then(response => ({
                                success: response.successCount,
                                failure: response.failureCount
                            }))
                    );
                }
            }

            // Wait for all batches to complete
            const results = await Promise.all(batches);
            
            // Calculate total success/failure
            const totals = results.reduce((acc, result) => ({
                success: acc.success + result.success,
                failure: acc.failure + result.failure
            }), { success: 0, failure: 0 });

            // Update notification status
            await admin.firestore()
                .collection('notifications')
                .doc(notificationId)
                .update({
                    status: 'sent',
                    successCount: totals.success,
                    failureCount: totals.failure,
                    completedAt: admin.firestore.FieldValue.serverTimestamp()
                });

            // Delete from queue
            await snap.ref.delete();

            return { success: true, ...totals };
        } catch (error) {
            console.error('Error sending notification:', error);
            
            // Update notification status to error
            await admin.firestore()
                .collection('notifications')
                .doc(notificationId)
                .update({
                    status: 'error',
                    error: error.message,
                    completedAt: admin.firestore.FieldValue.serverTimestamp()
                });

            throw error;
        }
    });