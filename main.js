import OpenAI from 'openai';
import Parser from 'rss-parser';
import RSS from 'rss';
import { readFile, writeFile } from 'fs/promises';
import dotenv from 'dotenv'; 
import shelljs from 'shelljs'

let systemPrompt = `You are an unbiased language model tasked with rewriting the titles of U.S. Congress Bills and Presidential Executive Orders. Your goal is to produce neutral and descriptive titles and summaries that reflect the actual content without any political spin, emotional language, or propaganda. Follow these guidelines:

1. Focus on the factual content and primary objectives of the bill or order.
2. Avoid emotionally charged or value-laden words.
3. Maintain clarity, but be sure to include all the important details.
4. Use neutral language that does not favor any political perspective.
5. Do not use any Markdown formatting
6. Opt for longer summaries

When provided with a title and summary or full text, analyze the content to create a new title and summary that adheres to these principles. A second message containing the original link will be provided. Please use that link in the JSON below.

Please format the information into a JSON object with the structure provided below:

1. Title: [Your Title Here]
2. Summary: [Your Summary Here]
3. Link: [Original Link Here]

JSON Structure:
{
    "title": $title (String),
    "summary": $summary (String),
    "link": $link (String)
}


Replace the placeholders with the provided information and ensure the JSON is properly formatted. ONLY RESPOND WITH VALID JSON. Double check your work to make sure your response is valid JSON matching the specification above.
`;

let disclaimer = " Disclaimer: This content is AI generated. Use at your own risk. Please consult the original articles for accurate information."

dotenv.config(); 

let cache;
async function getCache() {
    try {
        cache = JSON.parse(await readFile('cache.json', 'utf8'));
    } catch {
        // if file errors or empty, assume nothing is in there
        cache = [];
    }
}

async function processFeed(sortedFeed) {
    let openAI = new OpenAI();
    const completions = await Promise.all(sortedFeed.map((async item => {
        let params = {
            model: 'gpt-4o-mini',
            messages: [
                {
                    role: 'system',
                    content: systemPrompt
                },
                {
                    role: 'user',
                    content: item.content
                }
            ]
        };

        return await openAI.chat.completions.create(params);
    })));

    const text = completions.map(comp => {
        return comp.choices[0].message.content
    });

    let json = text.map(t => {
        return JSON.parse(t);
    });

    return json 
}


async function fetchFeed() {
    const parser = new Parser();

    const feed = await parser.parseURL('https://www.whitehouse.gov/presidential-actions/feed');
    return feed.items
        .sort((i1, i2) => i1.pubDate > i2.pubDate)
        .filter(item => !cache.some(i => i.link === item.link));
}

async function createRSSFeed(json) {
    let rssFeed = new RSS({
        title: "Presidential Action Summaries"
    });
    
    json.forEach(j => {
        rssFeed.item({
            title: j.title,
            description: j.summary + disclaimer,
            url: j.link
        });
    });
    
    await writeFile('actions_feed.xml', rssFeed.xml({ indent: true }));
}

async function writeHTML(json) {
    let htmlHead = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Presidential Actions</title>
    <link rel="stylesheet" href="styles.css"> <!-- Link to your CSS file -->
</head>
<body>
  <div class="container">
  <p><a href="actions_feed.xml">RSS</a> <a href="https://github.com/johnmahlon/GovernmentActionSummarizer">GitHub</a><br>
  <p>Updates everyday at midnight UTC.</p><br>
    <i><b>Disclaimer:</b> This content is AI generated. Use at your own risk. Consult original post for more accurate information. At some point, all content below goes through an LLM. Even the "original post" links may be hallucinated.</i></p>
    `;

    json.forEach(post => {
        htmlHead += `<h3>${post.title}</h3><i><a href="${post.link}">Original Post</a></i><br><p>${post.summary}</p><br>`;
    });


    let footer = `
    </div>
    </body>
</html>
    `;

    htmlHead += footer; 

    await writeFile('index.html', htmlHead);
}

await getCache(); 
 // make backup
await writeFile('cache-backup.json', JSON.stringify(cache, null, 2));
const feed = await fetchFeed();

if (feed.length === 0) {
    // get out if its empty!
    process.exit();
}

let json = await processFeed(feed);
json.concat(cache).slice(0, 10);

// overwrite new file
await writeFile('cache.json', JSON.stringify(json, null, 2));
await createRSSFeed(json);
await writeHTML(json);

shelljs.exec('git add .');
shelljs.exec('git commit -m "add feed"');
shelljs.exec('git push');

