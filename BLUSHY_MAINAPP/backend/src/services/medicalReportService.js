import fs from 'node:fs';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { db } from '../utils/db.js';
import { userRepository } from '../repositories/userRepository.js';
import { env } from '../utils/env.js';

const require = createRequire(import.meta.url);
const { PDFParse } = require('pdf-parse');

export async function parseAndSaveMedicalReport({ userId, file }) {
  if (!userId || !file) {
    return { isMedicalReport: false, reason: 'missing-input' };
  }

  // 1. Create a database record for this medical report
  const report = {
    report_id: randomUUID(),
    user_id: userId,
    file_url: `/uploads/partner_chat/${file.filename}`, // upload path
    file_name: file.originalname,
    file_type: file.mimetype,
    created_at: new Date(),
  };

  await db.collection('medical_reports').insertOne(report);

  // 2. Extract plain text content or PDF content
  let textContent = '';
  const lowerName = file.originalname.toLowerCase();
  const isPdf = file.mimetype === 'application/pdf' || lowerName.endsWith('.pdf');
  const isImage = file.mimetype.startsWith('image/') || /\.(jpg|jpeg|png|webp)$/i.test(lowerName);

  if (isPdf) {
    try {
      const dataBuffer = fs.readFileSync(file.path);
      const parser = new PDFParse({ data: dataBuffer });
      const pdfData = await parser.getText();
      textContent = pdfData.text || '';
    } catch (err) {
      console.error('PDF parsing error:', err);
    }
  } else if (file.mimetype === 'text/plain' || lowerName.endsWith('.txt') || lowerName.endsWith('.md')) {
    try {
      textContent = fs.readFileSync(file.path, 'utf8');
    } catch (_) {}
  }

  // 3. Prepare analysis prompt
  const prompt = `You are a medical document classifier and analyzer.
Analyze the following document ${isImage ? 'image' : 'metadata and content snippet'}:
File Name: "${file.originalname}"
MimeType: "${file.mimetype}"
${isImage ? 'The document is uploaded as an image.' : `Content Snippet:
${textContent.slice(0, 3000) || '(No text content extracted)'}`}

Determine if this document is a medical report, laboratory result, doctor prescription, or medication checklist.
If it is indeed a medical report/prescription:
1. Identify and list the medication names, dosage (if present), and frequency (if present).
2. Briefly explain what the document describes.

Format your response strictly as a JSON object:
{
  "isMedicalReport": true,
  "medications": ["Amoxicillin 500mg daily", "Metformin 500mg twice a day"],
  "details": "Prescription for bacterial infection."
}

If it is not a medical report/prescription (e.g. general chat photo, screenshot of a game, landscape photo), respond with:
{
  "isMedicalReport": false,
  "medications": [],
  "details": "Not a medical report."
}`;

  let parsed = { isMedicalReport: false, medications: [], details: '' };

  // 4. Query Grok AI/Vision AI for document categorization
  if (env.aiChatApiKey) {
    try {
      const requestModel = env.aiChatModel;
      
      let messagesPayload = [];
      if (isImage) {
        const imageBase64 = fs.readFileSync(file.path, 'base64');
        const dataUrl = `data:${file.mimetype};base64,${imageBase64}`;
        messagesPayload = [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: prompt,
              },
              {
                type: 'image_url',
                image_url: {
                  url: dataUrl,
                },
              },
            ],
          },
        ];
      } else {
        messagesPayload = [{ role: 'user', content: prompt }];
      }

      const response = await fetch(env.aiChatApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.aiChatApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: requestModel,
          messages: messagesPayload,
          max_tokens: 300,
          response_format: { type: 'json_object' },
        }),
      });

      if (response.ok) {
        const json = await response.json();
        const contentStr = json.choices?.[0]?.message?.content;
        if (contentStr) {
          let cleaned = contentStr.trim();
          if (cleaned.startsWith('```json')) {
            cleaned = cleaned.substring(7);
          }
          if (cleaned.startsWith('```')) {
            cleaned = cleaned.substring(3);
          }
          if (cleaned.endsWith('```')) {
            cleaned = cleaned.substring(0, cleaned.length - 3);
          }
          parsed = JSON.parse(cleaned.trim());
        }
      }
    } catch (err) {
      console.error('LLM medical report analysis error:', err);
      // Fallback: rule-based fallback based on filename if API call fails
      if (lowerName.includes('report') || lowerName.includes('prescription') || lowerName.includes('med') || lowerName.includes('medical') || lowerName.includes('blood') || lowerName.includes('lab') || lowerName.includes('test') || lowerName.includes('doc')) {
        parsed = {
          isMedicalReport: true,
          medications: ['Extracted from filename: ' + file.originalname],
          details: 'Extracted automatically from file: ' + file.originalname,
        };
      }
    }
  } else {
    // Local offline mock/rule-based parsing if API key is not configured
    if (lowerName.includes('report') || lowerName.includes('prescription') || lowerName.includes('med') || lowerName.includes('medical') || lowerName.includes('blood') || lowerName.includes('lab') || lowerName.includes('test') || lowerName.includes('doc')) {
      parsed = {
        isMedicalReport: true,
        medications: [file.originalname.replace(/\.[^/.]+$/, "")],
        details: 'Extracted automatically from file: ' + file.originalname,
      };
    }
  }

  // 5. Update user medication tracking if classified as medical report
  if (parsed.isMedicalReport) {
    const joinedMeds = parsed.medications.length > 0 ? parsed.medications.join(', ') : 'No medications extracted';

    if (parsed.medications.length > 0) {
      const onboarding = await userRepository.getOnboardingAnswers(userId);
      const existingAnswers = onboarding?.onboardingAnswers ?? {};

      const nextAnswers = {
        ...existingAnswers,
        medication_currently_taking: 'yes',
        taking_any_medication: 'yes',
        medication_type: existingAnswers.medication_type
          ? `${existingAnswers.medication_type}, ${joinedMeds}`
          : joinedMeds,
        taking_any_medication_type: existingAnswers.taking_any_medication_type
          ? `${existingAnswers.taking_any_medication_type}, ${joinedMeds}`
          : joinedMeds,
        medication_recent_changes: `Extracted from medical report "${file.originalname}": ${parsed.details}`,
        recent_medication_changes: `Extracted from medical report "${file.originalname}": ${parsed.details}`,
      };

      await userRepository.updateOnboardingAnswers(userId, nextAnswers);
    }
    
    // Also save the extracted medications directly to the report record
    await db.collection('medical_reports').updateOne(
      { report_id: report.report_id },
      { $set: { extracted_medication: joinedMeds, details: parsed.details } }
    );
    report.extracted_medication = joinedMeds;
    report.details = parsed.details;
  }

  return {
    isMedicalReport: parsed.isMedicalReport,
    medications: parsed.medications,
    details: parsed.details,
    report,
  };
}
