import express from 'express';
import morgan from 'morgan';

process.on('uncaughtException', err => {
  console.error('UNCAUGHT EXCEPTION:', err);
  process.exit(1);
});

process.on('unhandledRejection', reason => {
  console.error('UNHANDLED REJECTION:', reason);
});

const app = express();
const PORT = 3000;

app.use(express.json());
app.use(morgan('dev')); 

app.get('/check-subreddit/:name', async (req, res) => {
  const subName = req.params.name.trim().toLowerCase().replace(/^r\//, '');

  if (!subName || subName.length < 3) {
    return res.status(400).json({ error: 'Invalid subreddit name' });
  }

  try {
    const response = await fetch(`https://www.reddit.com/r/${subName}/about.json`, {
      headers: {
        'User-Agent': 'MyRedditChecker/1.0 (by /u/Mina-olen-Mina)' // TODO make username an env variable
      }
    });

    let exists = false;
    let message = 'Subreddit not found';

    if (response.ok) {
      const data = await response.json();

      exists = !!data?.data?.display_name; 
      message = exists ? 'Subreddit exists' : 'Invalid or private subreddit';
    } else if (response.status === 404) {
      message = 'Subreddit does not exist (404)';
    } else {
      message = `Reddit returned ${response.status}`;
    }

    return res.json({
      subreddit: subName,
      exists,
      message
    });
  } catch (error) {
    console.error('Fetch error for', subName, ':', error);
    return res.status(500).json({ error: 'Could not check subreddit existence' });
  }
});


app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
