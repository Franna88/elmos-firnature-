#!/usr/bin/env node

const { google } = require('googleapis');
const fs = require('fs');
const path = require('path');

// Configuration - replace with your actual values or use environment variables
const CONFIG = {
    packageName: 'com.elmosfurniture.app',
    serviceAccountKeyPath: process.env.PLAY_STORE_SERVICE_ACCOUNT_PATH || './service-account.json',
    aabPath: process.argv[2] || './build/app/outputs/bundle/release/app-release.aab',
    track: process.argv[3] || 'production',
    releaseNotes: {
        'en-US': fs.readFileSync('./distribution/whatsnew/en-US.txt', 'utf8')
    }
};

async function uploadToPlayStore() {
    try {
        console.log('Starting upload to Google Play Store...');
        console.log(`Package: ${CONFIG.packageName}`);
        console.log(`Track: ${CONFIG.track}`);
        console.log(`AAB Path: ${CONFIG.aabPath}`);

        // Check if AAB file exists
        if (!fs.existsSync(CONFIG.aabPath)) {
            console.error(`Error: AAB file not found at ${CONFIG.aabPath}`);
            process.exit(1);
        }

        // Check if service account key file exists
        if (!fs.existsSync(CONFIG.serviceAccountKeyPath)) {
            console.error(`Error: Service account key file not found at ${CONFIG.serviceAccountKeyPath}`);
            console.error('Please provide a valid service account key file.');
            process.exit(1);
        }

        // Load the service account key file
        const key = require(path.resolve(CONFIG.serviceAccountKeyPath));

        // Setup authentication
        const auth = new google.auth.JWT(
            key.client_email,
            null,
            key.private_key,
            ['https://www.googleapis.com/auth/androidpublisher']
        );

        // Create Play Store client
        const androidpublisher = google.androidpublisher({
            version: 'v3',
            auth
        });

        // Create a new edit
        const edit = await androidpublisher.edits.insert({
            packageName: CONFIG.packageName
        });

        const editId = edit.data.id;
        console.log(`Created edit with ID: ${editId}`);

        // Upload the AAB
        console.log('Uploading AAB file...');
        const aabContent = fs.readFileSync(CONFIG.aabPath);

        const uploadResponse = await androidpublisher.edits.bundles.upload({
            packageName: CONFIG.packageName,
            editId,
            media: {
                mimeType: 'application/octet-stream',
                body: aabContent
            }
        });

        const versionCode = uploadResponse.data.versionCode;
        console.log(`Uploaded AAB with version code: ${versionCode}`);

        // Add release notes
        const releaseNotes = [];
        for (const [locale, notes] of Object.entries(CONFIG.releaseNotes)) {
            releaseNotes.push({
                language: locale,
                text: notes
            });
        }

        // Update the track
        console.log(`Updating the ${CONFIG.track} track...`);
        await androidpublisher.edits.tracks.update({
            packageName: CONFIG.packageName,
            editId,
            track: CONFIG.track,
            requestBody: {
                releases: [
                    {
                        versionCodes: [versionCode],
                        status: 'completed',
                        releaseNotes
                    }
                ]
            }
        });

        // Commit the changes
        console.log('Committing changes...');
        await androidpublisher.edits.commit({
            packageName: CONFIG.packageName,
            editId
        });

        console.log('Upload to Google Play Store completed successfully!');
    } catch (error) {
        console.error('Error uploading to Google Play Store:');
        console.error(error.message);
        if (error.response) {
            console.error(error.response.data);
        }
        process.exit(1);
    }
}

uploadToPlayStore();
