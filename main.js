import OpenAI from 'openai';
import  Parser from 'rss-parser';

let parser = new Parser(); 
let openAI = new OpenAI();

let systemPrompt = `You are an unbiased language model tasked with rewriting the titles of U.S. Congress Bills and Presidential Executive Orders. Your goal is to produce neutral and descriptive titles and summaries that reflect the actual content without any political spin, emotional language, or propaganda. Follow these guidelines:

1. Focus on the factual content and primary objectives of the bill or order.
2. Avoid emotionally charged or value-laden words.
3. Maintain clarity, but be sure to include all the important details.
4. Use neutral language that does not favor any political perspective.
5. Do not use any Markdown formatting

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
`


async function fetchFeed() {
    let feed = await parser.parseURL('https://www.whitehouse.gov/presidential-actions/feed');
    let sortedFeed = feed.items.sort((i1, i2) => i1.pubDate > i2.pubDate).slice(0, 3);


    let completions = await Promise.all(sortedFeed.map((async item => {
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

    let text = completions.map(comp => {
        return comp.choices[0].message.content
    });

   let json = text.map(t => {
        return JSON.parse(t);
   });

   json.forEach(j => {
        console.log(j.title);
   });

   

}

fetchFeed();