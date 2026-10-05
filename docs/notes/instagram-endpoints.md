# Instagram web endpoints observed (structure only)

Captured 2026-10-05 from instagram.com in a logged-in browser. Field names and types only: no message text, names, ids or tokens.
`doc_id`s are Instagram's query hashes and WILL change when the site is redeployed — when a feature stops working, re-capture its doc_id.
Rule for this project: only the endpoints listed under a feature may be called for that feature. Never call the ones marked DO NOT CALL.


## 1. Inbox
- POST /api/graphql, op `IGDThreadListProfessionalOffMsysPaginationQuery`, doc_id 28415566141432177
  vars: count, cursor, ig_inbox_folder, system_folder, id, + 3 __relay_internal__pv__ flags
  -> data.fetch__SlideMailbox.threads_by_system_folder_and_ig_inbox_folder.edges[].node.as_ig_direct_thread
     {id, thread_key, thread_fbid, thread_id, thread_title, is_group, users, usersWithoutViewer, viewer,
      last_activity_timestamp_ms(s), marked_as_unread(b), is_pin(b), is_muted(b), slide_messages, slide_read_receipts,
      thread_image_url, nicknames, folder, system_folder, messaging_folder_tag, thread_subtype, input_mode(n)}
     page_info {end_cursor, has_next_page}; 5 threads per page in this capture
- POST /api/graphql, op `IGDThreadDetailQuery`, doc_id 29619996517588618 (prefetched per visible thread)
  vars: min_uq_seq_id, thread_fbid, + 2 relay flags
  -> data.get_slide_thread_nullable.as_ig_direct_thread
     users[] {username, full_name, id, pk, fbid_v2, interop_messaging_user_fbid, profile_pic_url, is_verified,
              latest_reel_media(n), reel_media_seen_timestamp, friendship_status{following,blocking,is_restricted}}
     slide_messages.edges[].node {id, message_id, sender_fbid, sender, content(…), content_type(s), text_body, timestamp_ms(s),
              reactions, msg_reactions, replied_to_message(_id), is_pinned, igd_is_forwarded, offline_threading_id, …}
       page_info {start_cursor, end_cursor, has_previous_page, has_next_page}; 8 messages in initial page
     viewer {id, username, full_name, profile_pic_url, interop_messaging_user_fbid}
     slide_read_receipts[] {participant_fbid, watermark_timestamp_ms}, last_activity_timestamp_ms, marked_as_unread
- No WebSocket opened during this action (an existing socket from page load may exist; not captured).
- Other traffic: /ajax/bootloader-endpoint/, /ajax/navigation/, /ajax/bulk-route-definitions/ (JS/route plumbing, ignore).

## 2. Older messages in a thread (scroll up)
- POST /api/graphql op `IGDMessageListOffMsysQuery` doc_id 28742488222105007 (6 calls while scrolling)
  message node: {id, message_id, thread_fbid, offline_threading_id, sender_fbid, timestamp_ms(s), content_type(s), is_pinned, igd_is_forwarded,
   replied_to_message_id, replied_to_message{…}, reactions[], msg_reactions[], mentions[], expiration_timestamp_ms, view_expiration_timestamp_ms,
   tombstone_reason, is_reported, text_body(s|null),
   sender{name,id,igid,user_dict{username,full_name,profile_pic_url,friendship_status,interop_messaging_user_fbid,id}},
   content{ __typename, text_body, text_fragments[{plaintext,link_fragment}], is_reaction_action_log,
     attachments[{attachment_fbid,attachment_type(n),preview_cdn_url,preview_width,preview_height,attachment_cdn_url,*_fallback_url}]  (photos),
     videos[{…same…, dash_manifest}],
     audio_attachments[{attachment_fbid, waveform_data[n], playable_duration_ms(n), attachment_cdn_url}] (voice) } }
- NOT seen in this chat's data: shared reel/post/story-reply content (no xma-like key present) — need a chat that has one.
- No WebSocket created yet (ws list empty): realtime delivery may be an MQTT/WS opened at page load before the recorder → check later.

## 3. Send text (+ read receipts, reactions)  — ALL plain POST /api/graphql, NO websocket (ws list empty)
- `IGDirectTextSendMutation` doc 26911679871773184
  vars: ig_thread_igid, offline_threading_id, recipient_igids, replied_to_client_context, replied_to_item_id, reply_to_message_id, sampled, text,
        mentions, mentioned_user_ids, commands, forwarded_from_thread_id, is_forwarded_from_own_message, send_attribution
  -> data.xig_direct_text_send_with_slide_messaging_response {message_id, timestamp_ms, id}
- `useIGDMarkThreadAsReadMutation` doc 27399783383056109 (+ `useIGDMarkThreadAsReadValidationMutation` doc 35211594988486314), vars {metadata, data}
  -> data.xig_direct_item_seen_mutation_with_slide_messaging_response {participant_eimu_id, watermark_timestamp_ms}
- `IGDirectReactionSendMutation` doc 24374451552236906, vars {input} -> …slide_message.reactions[{reaction, reaction_timestamp_ms, sender_fbid}]
- `IGDInboxHeaderOffMsysQuery` doc 28784987187762419 vars {min_uq_seq_id, thread_fbid}
- Request body common fields (names only): av, __d, __user, __a, __req, __hs, dpr, __ccg, __rev, __s, __hsi, __dyn, __csr, __hsdp, __hblp, __sjsp,
  __comet_req, fb_dtsg, jazoest, lsd, __spin_r/b/t, __crn, fb_api_caller_class, fb_api_req_friendly_name, server_timestamps, variables, doc_id.
  => fb_dtsg / lsd / jazoest are per-session page tokens; the native client must obtain them from an instagram.com page load (WKWebView can hand them over).
  => doc_ids are Relay query hashes: they change when Instagram redeploys → expect periodic breakage (known risk).

## 4. Send photo — two steps, both plain HTTP (no websocket)
1. POST www.instagram.com/ajax/mercury/upload.php (multipart; body field `farr` = the file; query qpl_active_flow_ids)
   -> {payload:{uploadID, metadata:{"0":{image_id, filename, filetype, fbid(n), src}}}}   (fbid = attachment id)
2. POST /api/graphql `IGDirectMediaSendMutation` doc 25766288509716264
   vars: attachment_fbid, thread_id, offline_threading_id, reply_to_message_id, forwarded_from_thread_id, is_forwarded_from_own_message
   -> data.xig_direct_media_send_with_slide_messaging_response {message_id, timestamp_ms, id}
- Also fires POST /ajax/bz (telemetry, ignore).

## 5. Voice send — NOT captured (browser pane has no microphone). Receiving side known (audio_attachments in message content).

## 6. Search people
- `PolarisSearchBoxRefetchableQuery` doc 27706427925724183, vars {data, hasQuery}  — fires once per keystroke (5 calls)
  -> data.xdt_api__v1__fbsearch__topsearch_connection {users[{position, user{username, full_name, pk, id, is_verified, profile_pic_url,
     hd_profile_pic_url_info{url}, search_social_context, search_social_context_snippet_type, unseen_count, live_broadcast_*, is_unpublished}}],
     hashtags[], places[], see_more, inform_module, rank_token}
  (the web client ALSO returns hashtags/places — we just ignore them: no discovery surfaces)
- `PolarisSearchNullStateQuery` doc 38466302779627407 (recent searches before typing) -> data.xig_recent_searches.recent_searches[{user|hashtag|place|keyword}]
- `IGDOmniPickerNullStateListQuery` doc 27657376130569675 vars {input} (new-message picker) -> get_paginated_share_sheet_ranked_items.ranked_items[]
- NOTE: suggested accounts (the "keep suggested accounts" feature) are NOT in the search null state — they come from somewhere else (profile page "similar accounts"?). Check on profile.
- Request budget note: web client fires a request per keystroke; native client should debounce (~300ms).

## 7. Profile (page load fires these in parallel)
- `PolarisProfilePageContentQuery` doc 28036671149327607 vars {id, enable_integrity_filters, + 5 relay flags}
  -> data.user {pk,id,username,full_name,biography,biography_with_entities,bio_links[],external_url,profile_pic_url,hd_profile_pic_url_info.url,
     is_private,is_verified,is_business,category,follower_count,following_count,media_count,total_clips_count,mutual_followers_count,
     friendship_status{following,followed_by,outgoing_request,incoming_request,blocking,muting,is_restricted,is_bestie,…},
     latest_reel_media(n = has story), account_type, has_chaining, remove_message_entrypoint, profile_context_facepile_users[]…}
- `PolarisProfilePostsQuery` doc 28991540097136703 (vars data, username, 3 relay flags) = first page of grid
  `PolarisProfilePostsTabContentQuery_connection` doc 29240983615539641 vars {after, before, first, last, data, username, include_multi_captions, flags} = pagination
  -> data.xdt_api__v1__feed__user_timeline_graphql_connection.edges[].node {code, pk, id, taken_at, caption{text,created_at}, image_versions2.candidates[],
     video_versions, video_dash_manifest, original_width/height, like_count, comment_count, has_liked, like_and_view_counts_disabled, user{…}, carousel?…}
- `PolarisProfileStoryHighlightsTrayContentQuery` doc 26970053832668570 vars {user_id}
  -> data.highlights.edges[].node {id, title, cover_media.cropped_image_version.url, user{username,id}}; page_info
- `PolarisProfileSuggestedUsersWithPreloadableQuery` doc 27929823133325729 vars {module, target_id}  ← "suggested accounts" live here
  -> data.xdt_api__v1__discover__chaining.users[] {pk,id,username,full_name,profile_pic_url,is_verified,is_private,friendship_status{…},social_context}
  (this is Instagram's "similar accounts" discovery module; we will call it only when the user taps "Suggested" — keep scope small)
- `PolarisProfileNoteBubbleQuery` doc 38260824646898178 vars {user_id}  (their Note bubble)
- `PolarisProfileDirectOrPartnershipInboxMessageEligibilityQuery` doc 26821612144133136 vars {ig_creator_user_id} (can we DM them)
- `usePolarisRegisterInRecentSearchesMutation` doc 27030919246576984 vars {entity_id, entity_name, entity_type}
- Highlights viewer: `PolarisStoriesV3HighlightsPageQuery` doc 28325328583775973 vars {initial_reel_id, reel_ids, first, last, flag}
  (+ `…PaginationQuery` doc 28338439489156504)
  -> data.xdt_api__v1__feed__reels_media__connection.edges[].node {id, items[{pk,id,code,media_type,taken_at,expiring_at,image_versions2,video_versions,
     video_dash_manifest,video_duration,has_audio,can_reply,viewer_count,viewers,caption,story_* stickers…}], user{…}}
- Mark story seen: `PolarisStoriesV3SeenMutation` doc 26234228992942885 vars {reelId, reelMediaId, reelMediaOwnerId, reelMediaTakenAt, viewSeenAt}
  -> data.xdt_mark_story_reel_seen {__typename}
- Media bytes come from CDN video/image URLs on scontent/video hosts (query params _nc_*, oh, oe, bytestart/byteend → range requests). No extra auth header seen in names.

## 8a. Stories tray + viewer
- `PolarisStoriesV3TrayContainerQuery` doc 27703822975903310 vars {data, suggestedUsersData}
  -> data.xdt_api__v1__feed__reels_tray.tray[] {id, reel_type, user{pk,username,profile_pic_url,hd_profile_pic_url_info,latest_reel_media,reel_media_seen_timestamp},
     seen(n), latest_reel_media(n), expiring_at, ranked_position, seen_ranked_position, muted, has_besties_media, latest_besties_reel_media}
     + xdt_viewer.user{username,id,profile_pic_url}; also `ayml.groups[]` (suggested people — IGNORE) and `broadcasts[]` (live — ignore)
- Viewer: `PolarisStoriesV3ReelPageGalleryQuery` doc 28262315486766731 vars {initial_reel_id, reel_ids, first, last, flag}
  and `…PaginationQuery` doc 28606543452290985 vars {after,before,first,initial_reel_id,is_highlight,last,reel_ids,flag}
  -> data.xdt_api__v1__feed__reels_media__connection.edges[].node {id, items[story items as in highlights], user{…}, seen(n), reel_type, can_reshare, muted}
- Seen: `PolarisStoriesV3SeenMutation` doc 26234228992942885 (fired once per story item viewed; 7 times)
- Like a story: `usePolarisStoriesV4LikeMutationLikeMutation` doc 26938887309082050 vars {input} -> data.xig_send_story_like
  (fired twice during the capture — a like then unlike, or an accidental double-tap)
- !!! DO NOT CALL (attention firewall): `PolarisStoriesV3AdsPoolQuery` (injects ads into stories), `PolarisFeedTimelineRootV2Query` /
  `PolarisFeedRootPaginationCachedQuery_subscribe` (the home feed, fired on Home page load), the `suggestedUsersData`/`ayml` parts of the tray.

## 8b. Post a story (mobile web /create/story/; needs screen.orientation = portrait or the page says "Rotate your device")
1. POST i.instagram.com/rupload_igphoto/fb_uploader_<id>  (raw image body)  -> {upload_id, status}
2. POST www.instagram.com/api/v1/media/configure_to_story/  form fields: upload_id, caption, configure_mode, share_to_facebook,
   share_to_fb_destination_id, share_to_fb_destination_type   -> {media{id, pk, expiring_at, media_type, …}}
- The web creator has NO text/stickers and NO Close Friends option. So "text on stories" = we render the text INTO the image on the phone, then upload it.
  Close-friends audience (configure_mode value?) is unknown — verify later.
- Seen but never to be called: GET /api/v1/discover/web/explore_grid/ (Explore), fired by the page shell.

## NOT captured (needs a later discovery pass)
voice-message send (browser pane has no mic), shared reel/post/story-reply message shapes in DMs, follow/unfollow, like a post, notes (write),
Close Friends, "missed call" item shape in a thread, how new messages arrive in real time (no WebSocket seen -> may be polling or a socket opened before the recorder).
