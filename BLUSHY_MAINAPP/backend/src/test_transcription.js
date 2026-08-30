import fs from 'node:fs';
import { env } from './utils/env.js';

async function run() {
  console.log('Reading webm file...');
  const base64Data = fs.readFileSync('uploads/partner_chat/1784379564170-953504896.webm', 'base64');
  const dataUrl = `data:audio/webm;base64,${base64Data}`;

  const prompt = `You are a professional multilingual speech transcriber. 
The user has spoken in a combination of English and one or more Indian languages (like Hindi, Tamil, Telugu, Kannada, Marathi, Bengali).
Your task is to transcribe the audio with >95% word accuracy:
1. Focus on the primary speaker and completely ignore any background noise, static hums, music, or background voices.
2. Filter out stutters and unnecessary filler words (such as 'um', 'uh', 'ah') to produce a clean verbatim transcription.
3. Preserve the exact languages and scripts used by the speaker.
4. If they speak in English, transcribe in English (Latin script).
5. If they speak in Hindi, transcribe in Hindi (using Devanagari script).
6. If they speak in Tamil, transcribe in Tamil (using Tamil script).
7. If they speak in Kannada, transcribe in Kannada (using Kannada script).
8. If they speak in Telugu, transcribe in Telugu (using Telugu script).
9. If they speak in Bengali, transcribe in Bengali (using Bengali script).
10. Do NOT translate any section. If they speak in multiple languages in sequence (e.g. English, then Kannada, then Tamil), transcribe each part in its respective language and script.
11. Output only the final transcription text. Do not write any explanations, preambles, or meta-comments.`;

  console.log('Sending request to Gemini 2.5 Flash...');
  const response = await fetch(env.aiChatApiUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.aiChatApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'google/gemini-2.5-flash',
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: prompt,
            },
            {
              type: 'input_audio',
              input_audio: {
                data: base64Data,
                format: 'webm',
              },
            },
          ],
        },
      ],
      max_tokens: 300,
    }),
  });

  console.log('Response status:', response.status);
  const json = await response.json();
  console.log('Full JSON response:', JSON.stringify(json, null, 2));
  const transcription = json.choices?.[0]?.message?.content;
  console.log('\nGemini Transcription:', transcription);

  process.exit(0);
}

run().catch(console.error);
