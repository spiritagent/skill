#!/usr/bin/env python3
"""
Spirit Agent Twitter client using twikit (cookie-based, no API key needed).
Usage: python3 twitter.py <action> [args...]

TWEETS:
  post <text>                          Post a tweet
  reply <tweet_id> <text>              Reply to a tweet
  quote <tweet_id> <text>              Quote tweet
  like <tweet_id>                      Like a tweet
  unlike <tweet_id>                    Unlike a tweet
  retweet <tweet_id>                   Retweet
  unretweet <tweet_id>                 Undo retweet
  bookmark <tweet_id>                  Bookmark a tweet
  unbookmark <tweet_id>               Remove bookmark
  delete <tweet_id>                    Delete own tweet
  tweet <tweet_id>                     Get a tweet by ID
  thread <text1> | <text2> | ...       Post a thread (pipe-separated)

USERS:
  follow <user_id>                     Follow user
  unfollow <user_id>                   Unfollow user
  block <user_id>                      Block user
  unblock <user_id>                    Unblock user
  mute <user_id>                       Mute user
  unmute <user_id>                     Unmute user
  user <username>                      Get user info by username
  user_id <user_id>                    Get user info by ID
  followers <username> [count]         Get user's followers
  following <username> [count]         Get user's following

SEARCH & DISCOVERY:
  search <query> [count]               Search tweets
  search_users <query> [count]         Search users
  timeline [count]                     Get home timeline
  user_tweets <username> [count]       Get user's tweets
  notifications [count]                Get notifications
  trends                               Get trending topics
  likers <tweet_id>                    Get users who liked a tweet
  retweeters <tweet_id>               Get users who retweeted

DMs:
  dm <user_id> <text>                  Send a DM
  dm_history <user_id> [count]         Get DM conversation

MEDIA:
  post_media <text> <media_path>       Post tweet with image/video
"""

import asyncio
import json
import os
import sys

from twikit import Client

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, '..', '.env')
COOKIES_FILE = os.path.join(SCRIPT_DIR, '..', 'twitter_cookies.json')

# Actions that get auto-reported to platform
REPORTABLE_ACTIONS = {'post', 'reply', 'quote', 'like', 'retweet', 'follow', 'unfollow', 'bookmark', 'delete', 'thread'}

def load_env():
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

async def get_client(env):
    proxy = env.get('TWITTER_PROXY', '') or None
    client = Client('en-US', proxy=proxy)
    
    if os.path.exists(COOKIES_FILE):
        client.load_cookies(COOKIES_FILE)
        return client
    
    auth_token = env.get('TWITTER_AUTH_TOKEN', '')
    ct0 = env.get('TWITTER_CT0', '')
    
    if auth_token and ct0:
        client.set_cookies({'auth_token': auth_token, 'ct0': ct0})
        client.save_cookies(COOKIES_FILE)
        return client
    
    print(json.dumps({'error': 'No Twitter cookies found. Set TWITTER_AUTH_TOKEN and TWITTER_CT0 in .env'}))
    sys.exit(1)

def serialize_tweet(t):
    return {
        'id': t.id,
        'text': t.text,
        'user': t.user.screen_name if t.user else None,
        'user_name': t.user.name if t.user else None,
        'user_avatar': t.user.profile_image_url if t.user else None,
        'created_at': str(t.created_at) if t.created_at else None,
        'likes': t.favorite_count,
        'retweets': t.retweet_count,
        'replies': t.reply_count if hasattr(t, 'reply_count') else None,
        'views': t.view_count if hasattr(t, 'view_count') else None,
    }

def serialize_user(u):
    return {
        'id': u.id,
        'name': u.name,
        'username': u.screen_name,
        'bio': u.description,
        'followers': u.followers_count,
        'following': u.following_count,
        'tweets': u.statuses_count,
        'avatar': u.profile_image_url if hasattr(u, 'profile_image_url') else None,
        'verified': u.is_blue_verified if hasattr(u, 'is_blue_verified') else None,
    }

async def report_to_platform(client, env, action, result, args):
    """Auto-report social actions to platform with parent tweet metadata."""
    platform_url = env.get('PLATFORM_API_URL', '')
    platform_key = env.get('PLATFORM_API_KEY', '')
    if not platform_url or not platform_key:
        return
    
    try:
        import urllib.request
        from datetime import datetime, timezone

        # Fetch referenced tweet metadata
        parent_content = None
        parent_author = None
        parent_author_name = None
        parent_author_avatar = None
        ref_tweet_id = None

        if action in ('like', 'retweet', 'bookmark'):
            ref_tweet_id = args[0] if args else None
        elif action in ('reply', 'quote'):
            ref_tweet_id = result.get('reply_to', result.get('quoted'))

        if ref_tweet_id:
            try:
                tweets = await client.get_tweets_by_ids([ref_tweet_id])
                if tweets:
                    tweet = tweets[0]
                    parent_content = tweet.text
                    if tweet.user:
                        parent_author = tweet.user.screen_name
                        parent_author_name = tweet.user.name
                        parent_author_avatar = tweet.user.profile_image_url
            except Exception:
                pass

        ext_id = (result.get('tweet_id') or result.get('liked') or result.get('unliked') or
                  result.get('retweeted') or result.get('unretweeted') or result.get('followed') or
                  result.get('unfollowed') or result.get('bookmarked') or result.get('unbookmarked') or
                  result.get('deleted') or '')

        parent_ext_id = result.get('reply_to', result.get('quoted', ''))
        parent_url = (f"https://x.com/{parent_author}/status/{parent_ext_id}" if parent_author and parent_ext_id
                      else f"https://x.com/i/status/{parent_ext_id}" if parent_ext_id else None)

        if action in ('follow', 'unfollow'):
            ext_url = f"https://x.com/intent/user?user_id={ext_id}" if ext_id else None
        elif ext_id:
            ext_url = f"https://x.com/i/status/{ext_id}"
        else:
            ext_url = None

        report_data = json.dumps({
            'platform': 'x',
            'action_type': action,
            'content': result.get('text', ''),
            'external_id': ext_id,
            'external_url': ext_url,
            'parent_external_id': parent_ext_id,
            'parent_external_url': parent_url,
            'parent_content': parent_content,
            'parent_author': parent_author,
            'parent_author_name': parent_author_name,
            'parent_author_avatar': parent_author_avatar,
            'posted_at': datetime.now(timezone.utc).isoformat(),
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
        pass


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
        # === TWEETS ===
        
        if action == 'post':
            text = ' '.join(args) if args else ''
            if not text:
                print(json.dumps({'error': 'Text required'})); sys.exit(1)
            tweet = await client.create_tweet(text)
            result = {'ok': True, 'tweet_id': tweet.id, 'text': text}
        
        elif action == 'reply':
            if len(args) < 2:
                print(json.dumps({'error': 'Usage: reply <tweet_id> <text>'})); sys.exit(1)
            tweet_id = args[0]
            text = ' '.join(args[1:])
            tweet = await client.create_tweet(text, reply_to=tweet_id)
            result = {'ok': True, 'tweet_id': tweet.id, 'reply_to': tweet_id, 'text': text}
        
        elif action == 'quote':
            if len(args) < 2:
                print(json.dumps({'error': 'Usage: quote <tweet_id> <text>'})); sys.exit(1)
            tweet_ref = args[0]
            text = ' '.join(args[1:])
            if not tweet_ref.startswith('http'):
                tweet_ref = f'https://x.com/i/status/{tweet_ref}'
            tweet = await client.create_tweet(text, attachment_url=tweet_ref)
            result = {'ok': True, 'tweet_id': tweet.id, 'quoted': args[0], 'text': text}
        
        elif action == 'thread':
            # Thread: texts separated by |
            text = ' '.join(args) if args else ''
            if not text:
                print(json.dumps({'error': 'Usage: thread <text1> | <text2> | ...'})); sys.exit(1)
            parts = [p.strip() for p in text.split('|') if p.strip()]
            if len(parts) < 2:
                print(json.dumps({'error': 'Thread needs at least 2 parts separated by |'})); sys.exit(1)
            tweet_ids = []
            reply_to = None
            for part in parts:
                tweet = await client.create_tweet(part, reply_to=reply_to)
                tweet_ids.append(tweet.id)
                reply_to = tweet.id
            result = {'ok': True, 'tweet_ids': tweet_ids, 'parts': len(parts), 'text': parts[0]}
        
        elif action == 'like':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            await client.favorite_tweet(args[0])
            result = {'ok': True, 'liked': args[0]}
        
        elif action == 'unlike':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            await client.unfavorite_tweet(args[0])
            result = {'ok': True, 'unliked': args[0]}
        
        elif action == 'retweet':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            await client.retweet(args[0])
            result = {'ok': True, 'retweeted': args[0]}
        
        elif action == 'unretweet':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            await client.delete_retweet(args[0])
            result = {'ok': True, 'unretweeted': args[0]}
        
        elif action == 'bookmark':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            await client.bookmark_tweet(args[0])
            result = {'ok': True, 'bookmarked': args[0]}
        
        elif action == 'unbookmark':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            await client.delete_bookmark(args[0])
            result = {'ok': True, 'unbookmarked': args[0]}
        
        elif action == 'delete':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            await client.delete_tweet(args[0])
            result = {'ok': True, 'deleted': args[0]}
        
        elif action == 'tweet':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            tweets = await client.get_tweets_by_ids([args[0]])
            if tweets:
                result = {'ok': True, 'tweet': serialize_tweet(tweets[0])}
            else:
                result = {'ok': False, 'error': 'Tweet not found'}
        
        # === USERS ===
        
        elif action == 'follow':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            await client.follow_user(args[0])
            result = {'ok': True, 'followed': args[0]}
        
        elif action == 'unfollow':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            await client.unfollow_user(args[0])
            result = {'ok': True, 'unfollowed': args[0]}
        
        elif action == 'block':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            await client.block_user(args[0])
            result = {'ok': True, 'blocked': args[0]}
        
        elif action == 'unblock':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            await client.unblock_user(args[0])
            result = {'ok': True, 'unblocked': args[0]}
        
        elif action == 'mute':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            await client.mute_user(args[0])
            result = {'ok': True, 'muted': args[0]}
        
        elif action == 'unmute':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            await client.unmute_user(args[0])
            result = {'ok': True, 'unmuted': args[0]}
        
        elif action == 'user':
            if not args:
                print(json.dumps({'error': 'Username required'})); sys.exit(1)
            user = await client.get_user_by_screen_name(args[0])
            result = {'ok': True, 'user': serialize_user(user)}
        
        elif action == 'user_id':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            user = await client.get_user_by_id(args[0])
            result = {'ok': True, 'user': serialize_user(user)}
        
        elif action == 'followers':
            if not args:
                print(json.dumps({'error': 'Username required'})); sys.exit(1)
            user = await client.get_user_by_screen_name(args[0])
            count = int(args[1]) if len(args) > 1 else 20
            users = await client.get_user_followers(user.id, count=count)
            result = {'ok': True, 'users': [serialize_user(u) for u in users]}
        
        elif action == 'following':
            if not args:
                print(json.dumps({'error': 'Username required'})); sys.exit(1)
            user = await client.get_user_by_screen_name(args[0])
            count = int(args[1]) if len(args) > 1 else 20
            users = await client.get_user_following(user.id, count=count)
            result = {'ok': True, 'users': [serialize_user(u) for u in users]}
        
        # === SEARCH & DISCOVERY ===
        
        elif action == 'search':
            if not args:
                print(json.dumps({'error': 'Query required'})); sys.exit(1)
            # Last arg might be count if it's a digit
            if len(args) > 1 and args[-1].isdigit():
                count = int(args[-1])
                query = ' '.join(args[:-1])
            else:
                count = 20
                query = ' '.join(args)
            tweets = await client.search_tweet(query, 'Latest', count=count)
            result = {'ok': True, 'tweets': [serialize_tweet(t) for t in tweets]}
        
        elif action == 'search_users':
            if not args:
                print(json.dumps({'error': 'Query required'})); sys.exit(1)
            if len(args) > 1 and args[-1].isdigit():
                count = int(args[-1])
                query = ' '.join(args[:-1])
            else:
                count = 20
                query = ' '.join(args)
            users = await client.search_user(query, count=count)
            result = {'ok': True, 'users': [serialize_user(u) for u in users]}
        
        elif action == 'timeline':
            count = int(args[0]) if args else 50
            tweets = await client.get_timeline(count=count)
            result = {'ok': True, 'tweets': [serialize_tweet(t) for t in tweets[:count]]}
        
        elif action == 'user_tweets':
            if not args:
                print(json.dumps({'error': 'Username required'})); sys.exit(1)
            user = await client.get_user_by_screen_name(args[0])
            count = int(args[1]) if len(args) > 1 else 20
            tweets = await client.get_user_tweets(user.id, 'Tweets', count=count)
            result = {'ok': True, 'tweets': [serialize_tweet(t) for t in tweets]}
        
        elif action == 'notifications':
            count = int(args[0]) if args else 20
            notifs = await client.get_notifications('All', count=count)
            result = {'ok': True, 'notifications': [serialize_tweet(t) for t in notifs]}
        
        elif action == 'trends':
            trends = await client.get_trends('trending')
            result = {'ok': True, 'trends': [{'name': t.name, 'tweet_count': t.tweet_count if hasattr(t, 'tweet_count') else None} for t in trends]}
        
        elif action == 'likers':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            count = int(args[1]) if len(args) > 1 else 20
            users = await client.get_favoriters(args[0], count=count)
            result = {'ok': True, 'users': [serialize_user(u) for u in users]}
        
        elif action == 'retweeters':
            if not args:
                print(json.dumps({'error': 'Tweet ID required'})); sys.exit(1)
            count = int(args[1]) if len(args) > 1 else 20
            users = await client.get_retweeters(args[0], count=count)
            result = {'ok': True, 'users': [serialize_user(u) for u in users]}
        
        # === DMs ===
        
        elif action == 'dm':
            if len(args) < 2:
                print(json.dumps({'error': 'Usage: dm <user_id> <text>'})); sys.exit(1)
            user_id = args[0]
            text = ' '.join(args[1:])
            msg = await client.send_dm(user_id, text)
            result = {'ok': True, 'dm_sent': user_id, 'text': text}
        
        elif action == 'dm_history':
            if not args:
                print(json.dumps({'error': 'User ID required'})); sys.exit(1)
            count = int(args[1]) if len(args) > 1 else 20
            messages = await client.get_dm_history(args[0], max_id=None)
            result = {
                'ok': True,
                'messages': [{
                    'id': m.id,
                    'text': m.text,
                    'sender_id': m.sender_id,
                    'time': str(m.time) if hasattr(m, 'time') else None,
                } for m in (messages[:count] if messages else [])]
            }
        
        # === MEDIA ===
        
        elif action == 'post_media':
            if len(args) < 2:
                print(json.dumps({'error': 'Usage: post_media <text> <media_path>'})); sys.exit(1)
            media_path = args[-1]
            text = ' '.join(args[:-1])
            if not os.path.exists(media_path):
                print(json.dumps({'error': f'File not found: {media_path}'})); sys.exit(1)
            media_id = await client.upload_media(media_path)
            tweet = await client.create_tweet(text, media_ids=[media_id])
            result = {'ok': True, 'tweet_id': tweet.id, 'text': text, 'media': media_path}
        
        else:
            print(json.dumps({'error': f'Unknown action: {action}. Run without args for help.'}))
            sys.exit(1)
        
        # Auto-report to platform
        if action in REPORTABLE_ACTIONS:
            await report_to_platform(client, env, action, result, args)
        
        print(json.dumps(result))
    
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())
