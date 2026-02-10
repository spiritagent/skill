#!/usr/bin/env python3
"""
Spirit Agent Twitter client using twikit (cookie-based, no API key needed).
Usage: python3 twitter.py <action> [args...]

Actions:
  post <text>                          Post a tweet
  reply <tweet_id> <text>              Reply to a tweet
  quote <tweet_id> <text>              Quote tweet
  like <tweet_id>                      Like a tweet
  unlike <tweet_id>                    Unlike a tweet
  retweet <tweet_id>                   Retweet
  unretweet <tweet_id>                 Undo retweet
  follow <user_id>                     Follow user
  unfollow <user_id>                   Unfollow user
  bookmark <tweet_id>                  Bookmark a tweet
  unbookmark <tweet_id>                Remove bookmark
  delete <tweet_id>                    Delete own tweet
  search <query>                       Search tweets
  timeline                             Get home timeline
  user <username>                       Get user info
  user_tweets <username>               Get user's tweets
"""

import asyncio
import json
import os
import sys

from twikit import Client

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, '..', '.env')
COOKIES_FILE = os.path.join(SCRIPT_DIR, '..', 'twitter_cookies.json')

def load_env():
    """Load .env file"""
    env = {}
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, _, val = line.partition('=')
                    val = val.strip().strip('"').strip("'")
                    env[key.strip()] = val
    return env

def get_proxy(env):
    """Build proxy URL from env"""
    proxy_url = env.get('TWITTER_PROXY', '')
    if proxy_url:
        return proxy_url
    return None

async def get_client(env):
    """Create and authenticate twikit client"""
    proxy = get_proxy(env)
    client = Client('en-US', proxy=proxy)
    
    # Try loading saved cookies first
    if os.path.exists(COOKIES_FILE):
        client.load_cookies(COOKIES_FILE)
        return client
    
    # Fall back to cookie injection from env
    auth_token = env.get('TWITTER_AUTH_TOKEN', '')
    ct0 = env.get('TWITTER_CT0', '')
    
    if auth_token and ct0:
        client.set_cookies({
            'auth_token': auth_token,
            'ct0': ct0,
        })
        # Save for next time
        client.save_cookies(COOKIES_FILE)
        return client
    
    print(json.dumps({'error': 'No Twitter cookies found. Set TWITTER_AUTH_TOKEN and TWITTER_CT0 in .env'}))
    sys.exit(1)

async def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    action = sys.argv[1]
    args = sys.argv[2:]
    env = load_env()
    client = await get_client(env)
    
    result = {}
    
    try:
        if action == 'post':
            text = ' '.join(args) if args else ''
            if not text:
                print(json.dumps({'error': 'Text required'}))
                sys.exit(1)
            tweet = await client.create_tweet(text)
            result = {'ok': True, 'tweet_id': tweet.id, 'text': text}
        
        elif action == 'reply':
            if len(args) < 2:
                print(json.dumps({'error': 'Usage: reply <tweet_id> <text>'}))
                sys.exit(1)
            tweet_id = args[0]
            text = ' '.join(args[1:])
            tweet = await client.create_tweet(text, reply_to=tweet_id)
            result = {'ok': True, 'tweet_id': tweet.id, 'reply_to': tweet_id, 'text': text}
        
        elif action == 'quote':
            if len(args) < 2:
                print(json.dumps({'error': 'Usage: quote <tweet_url_or_id> <text>'}))
                sys.exit(1)
            tweet_ref = args[0]
            text = ' '.join(args[1:])
            # twikit uses attachment_url for quote tweets
            if not tweet_ref.startswith('http'):
                tweet_ref = f'https://x.com/i/status/{tweet_ref}'
            tweet = await client.create_tweet(text, attachment_url=tweet_ref)
            result = {'ok': True, 'tweet_id': tweet.id, 'quoted': args[0], 'text': text}
        
        elif action == 'like':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'}))
                sys.exit(1)
            await client.favorite_tweet(args[0])
            result = {'ok': True, 'liked': args[0]}
        
        elif action == 'unlike':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'}))
                sys.exit(1)
            await client.unfavorite_tweet(args[0])
            result = {'ok': True, 'unliked': args[0]}
        
        elif action == 'retweet':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'}))
                sys.exit(1)
            await client.retweet(args[0])
            result = {'ok': True, 'retweeted': args[0]}
        
        elif action == 'unretweet':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'}))
                sys.exit(1)
            await client.delete_retweet(args[0])
            result = {'ok': True, 'unretweeted': args[0]}
        
        elif action == 'follow':
            if not args:
                print(json.dumps({'error': 'User ID required'}))
                sys.exit(1)
            await client.follow_user(args[0])
            result = {'ok': True, 'followed': args[0]}
        
        elif action == 'unfollow':
            if not args:
                print(json.dumps({'error': 'User ID required'}))
                sys.exit(1)
            await client.unfollow_user(args[0])
            result = {'ok': True, 'unfollowed': args[0]}
        
        elif action == 'bookmark':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'}))
                sys.exit(1)
            await client.bookmark_tweet(args[0])
            result = {'ok': True, 'bookmarked': args[0]}
        
        elif action == 'unbookmark':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'}))
                sys.exit(1)
            await client.delete_bookmark(args[0])
            result = {'ok': True, 'unbookmarked': args[0]}
        
        elif action == 'delete':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'}))
                sys.exit(1)
            await client.delete_tweet(args[0])
            result = {'ok': True, 'deleted': args[0]}
        
        elif action == 'search':
            query = ' '.join(args) if args else ''
            if not query:
                print(json.dumps({'error': 'Query required'}))
                sys.exit(1)
            tweets = await client.search_tweet(query, 'Latest', count=10)
            result = {
                'ok': True,
                'tweets': [{
                    'id': t.id,
                    'text': t.text,
                    'user': t.user.screen_name if t.user else None,
                    'created_at': str(t.created_at) if t.created_at else None,
                    'likes': t.favorite_count,
                    'retweets': t.retweet_count,
                } for t in tweets]
            }
        
        elif action == 'timeline':
            tweets = await client.get_timeline()
            result = {
                'ok': True,
                'tweets': [{
                    'id': t.id,
                    'text': t.text,
                    'user': t.user.screen_name if t.user else None,
                    'created_at': str(t.created_at) if t.created_at else None,
                    'likes': t.favorite_count,
                    'retweets': t.retweet_count,
                } for t in tweets[:20]]
            }
        
        elif action == 'user':
            if not args:
                print(json.dumps({'error': 'Username required'}))
                sys.exit(1)
            user = await client.get_user_by_screen_name(args[0])
            result = {
                'ok': True,
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'username': user.screen_name,
                    'bio': user.description,
                    'followers': user.followers_count,
                    'following': user.following_count,
                    'tweets': user.statuses_count,
                }
            }
        
        elif action == 'user_tweets':
            if not args:
                print(json.dumps({'error': 'Username required'}))
                sys.exit(1)
            user = await client.get_user_by_screen_name(args[0])
            tweets = await client.get_user_tweets(user.id, 'Tweets', count=10)
            result = {
                'ok': True,
                'tweets': [{
                    'id': t.id,
                    'text': t.text,
                    'created_at': str(t.created_at) if t.created_at else None,
                    'likes': t.favorite_count,
                    'retweets': t.retweet_count,
                } for t in tweets]
            }
        
        else:
            print(json.dumps({'error': f'Unknown action: {action}'}))
            sys.exit(1)
        
        # Auto-report to platform if configured
        platform_url = env.get('PLATFORM_API_URL', '')
        platform_key = env.get('PLATFORM_API_KEY', '')
        if platform_url and platform_key and action in ('post', 'reply', 'quote', 'like', 'retweet', 'follow', 'unfollow', 'bookmark', 'delete'):
            try:
                import urllib.request
                report_data = json.dumps({
                    'platform': 'x',
                    'action_type': action,
                    'content': result.get('text', ''),
                    'external_id': result.get('tweet_id', ''),
                    'posted_at': None,
                }).encode()
                req = urllib.request.Request(
                    f'{platform_url}/api/v1/social-actions',
                    data=report_data,
                    headers={
                        'Content-Type': 'application/json',
                        'Authorization': f'Bearer {platform_key}',
                    },
                    method='POST',
                )
                urllib.request.urlopen(req, timeout=5)
            except Exception:
                pass  # fire-and-forget
        
        print(json.dumps(result))
    
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())
