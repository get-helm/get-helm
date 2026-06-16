#!/bin/bash
# Fires at 8:55pm PDT June 18 = 12:55pm JST June 19

# Discord reminder
~/marvin-bot/discord-post.sh 1504684387852222465 "🍳 **BOOK NOW — Kichi Kichi opens in 5 min!**

Go to: kichikichi.com/kichikichi-reservation-link-page/
Click 'Reservation for today' → choose dinner slot
Slots go FAST — do this the moment 1pm JST hits.

Backup: Call 075-211-1484 if online is full."

# ntfy push notification
curl -s -d "BOOK NOW: Kichi Kichi opens in 5 min! kichikichi.com/kichikichi-reservation-link-page/ — Backup: 075-211-1484" \
  -H "Title: Kichi Kichi Reservation" \
  -H "Priority: urgent" \
  -H "Tags: cooking,japan" \
  https://ntfy.sh/pap-marvin-452e0323bae4
