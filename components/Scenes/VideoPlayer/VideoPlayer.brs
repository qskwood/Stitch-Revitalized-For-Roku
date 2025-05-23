sub handleContent()
    m.PlayVideo = CreateObject("roSGNode", "GetTwitchContent")
    m.PlayVideo.observeField("response", "OnResponse")
    m.PlayVideo.contentRequested = m.top.contentRequested.getFields()
    m.PlayVideo.functionName = "main"
    m.PlayVideo.control = "run"
end sub

function handleItemSelected()
    selectedRow = m.rowlist.content.getchild(m.rowlist.rowItemSelected[0])
    selectedItem = selectedRow.getChild(m.rowlist.rowItemSelected[1])
    ' m.top.playContent = true
    ' m.top.contentSelected = selectedItem
    m.PlayVideo = CreateObject("roSGNode", "GetTwitchContent")
    m.PlayVideo.observeField("response", "OnResponse")
    m.PlayVideo.contentRequested = selectedItem.getFields()
    m.PlayVideo.functionName = "main"
    m.PlayVideo.control = "run"
end function

function onResponse()
    ' content.ignoreStreamErrors = true
    m.top.content = m.PlayVideo.response
    m.top.metadata = m.PlayVideo.metadata
    playContent()
end function

sub taskStateChanged(event as object)
    print "Player: taskStateChanged(), id = "; event.getNode(); ", "; event.getField(); " = "; event.getData()
    state = event.GetData()
    if state = "done" or state = "stop"
        exitPlayer()
    end if
end sub

sub controlChanged()
    'handle orders by the parent/owner
    control = m.top.control
    if control = "play" then
        playContent()
    else if control = "stop" then
        exitPlayer()
    end if
end sub

sub initChat()
    if not m.top.chatStarted
        m.top.chatStarted = true
        m.chatWindow.channel_id = m.top.contentRequested.streamerId
        m.chatWindow.channel = m.top.contentRequested.streamerLogin
        if get_user_setting("ChatOption", "true") = "true"
            m.chatWindow.visible = true
            m.video.chatIsVisible = m.chatWindow.visible
        else
            m.chatWindow.visible = false
        end if
    end if
end sub

function onQualityChangeRequested()
    ? "[Video Wrapper] - Quality Change Requested: "; m.video.qualityChangeRequest
    new_content = CreateObject("roSGNode", "TwitchContentNode")
    new_content.setFields(m.top.contentRequested.getFields())
    new_content.setFields(m.top.metadata[m.video.qualityChangeRequest])
    m.top.content = new_content
    m.allowBreak = false
    exitPlayer()
    playContent()
    m.allowBreak = true
end function

sub configureVideoForLatency(video as object, isLive as boolean)
    ' Get user's latency preference
    latencyPreference = get_user_setting("preferred.latency", "low")
    isLowLatency = (latencyPreference = "low")

    if isLive and isLowLatency
        ' Minimal buffering configuration for live streams
        video.bufferingConfig = {
            initialBufferingMs: 500,
            minBufferMs: 1000,
            maxBufferMs: 3000,
            bufferForPlaybackMs: 500,
            bufferForPlaybackAfterRebufferMs: 1000,
            rebufferMs: 500
        }

        ' Disable adaptive bitrate to prevent quality switching
        video.enableDecoderCompatibility = false
        video.maxVideoDecodeResolution = "1080p"

        ' Conservative adaptive bitrate to prevent frequent switching
        video.adaptiveBitrateConfig = {
            initialBandwidthBps: 2000000,
            maxInitialBitrate: 3000000,
            minDurationForQualityIncreaseMs: 30000,
            maxDurationForQualityDecreaseMs: 5000,
            minDurationToRetainAfterDiscardMs: 2000,
            bandwidthMeterSlidingWindowMs: 5000
        }

        ? "[VideoPlayer] Configured for low latency mode"
    else if isLive
        ' Normal latency configuration for live streams
        video.bufferingConfig = {
            initialBufferingMs: 2000,
            minBufferMs: 5000,
            maxBufferMs: 15000,
            bufferForPlaybackMs: 2000,
            bufferForPlaybackAfterRebufferMs: 5000,
            rebufferMs: 2000
        }

        video.enableDecoderCompatibility = true

        ' Standard adaptive bitrate parameters
        video.adaptiveBitrateConfig = {
            initialBandwidthBps: 3000000,
            maxInitialBitrate: 6000000,
            minDurationForQualityIncreaseMs: 10000,
            maxDurationForQualityDecreaseMs: 25000,
            minDurationToRetainAfterDiscardMs: 5000,
            bandwidthMeterSlidingWindowMs: 10000
        }

        ? "[VideoPlayer] Configured for normal latency mode"
    else
        ' VOD configuration (not affected by latency settings)
        video.bufferingConfig = {
            initialBufferingMs: 3000,
            minBufferMs: 10000,
            maxBufferMs: 30000,
            bufferForPlaybackMs: 3000,
            bufferForPlaybackAfterRebufferMs: 8000,
            rebufferMs: 3000
        }

        video.enableDecoderCompatibility = true

        ? "[VideoPlayer] Configured for VOD playback"
    end if
end sub

sub playContent()
    if m.video <> invalid
        m.top.removeChild(m.video)
    end if

    isLiveContent = (m.top.contentRequested.contentType = "LIVE")
    isClipContent = (m.top.contentRequested.contentType = "CLIP")

    if isLiveContent
        quality_options = []
        if m.top.metadata <> invalid
            for each quality_option in m.top.metadata
                quality_options.push(quality_option.qualityID)
            end for
        end if
        m.video = m.top.CreateChild("StitchVideo")
        m.video.qualityOptions = quality_options
    else
        m.video = m.top.CreateChild("CustomVideo")
    end if

    ' Configure HTTP agent with enhanced headers for better compatibility
    httpAgent = CreateObject("roHttpAgent")
    httpAgent.setCertificatesFile("common:/certs/ca-bundle.crt")
    httpAgent.InitClientCertificates()
    httpAgent.enableCookies()

    ' Set different headers based on content type
    if isClipContent
        ' Enhanced clip-specific headers with proper authentication
        httpAgent.addheader("Accept", "video/mp4,video/webm,video/*,*/*")
        httpAgent.addheader("Accept-Encoding", "identity")
        httpAgent.addheader("Accept-Language", "en-US,en;q=0.9")
        httpAgent.addheader("Cache-Control", "no-cache")
        httpAgent.addheader("Connection", "keep-alive")
        httpAgent.addheader("DNT", "1")
        httpAgent.addheader("Origin", "https://www.twitch.tv")
        httpAgent.addheader("Pragma", "no-cache")
        httpAgent.addheader("Referer", "https://www.twitch.tv/")
        httpAgent.addheader("Sec-Ch-Ua", chr(34) + "Not_A Brand" + chr(34) + ";v=" + chr(34) + "8" + chr(34) + ", " + chr(34) + "Chromium" + chr(34) + ";v=" + chr(34) + "120" + chr(34) + ", " + chr(34) + "Google Chrome" + chr(34) + ";v=" + chr(34) + "120" + chr(34))
        httpAgent.addheader("Sec-Ch-Ua-Mobile", "?0")
        httpAgent.addheader("Sec-Ch-Ua-Platform", chr(34) + "Windows" + chr(34))
        httpAgent.addheader("Sec-Fetch-Dest", "video")
        httpAgent.addheader("Sec-Fetch-Mode", "cors")
        httpAgent.addheader("Sec-Fetch-Site", "cross-site")
        httpAgent.addheader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

        ' Add Twitch-specific headers for clips
        httpAgent.addheader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")
        httpAgent.addheader("X-Device-Id", CreateObject("roDeviceInfo").GetRandomUUID())

        ' Try to add authorization if we have a token
        authToken = get_user_setting("auth_token", "")
        if authToken <> ""
            httpAgent.addheader("Authorization", "Bearer " + authToken)
        end if

        ? "[VideoPlayer] Configured HTTP agent for clip with enhanced headers"
    else
        ' Live/VOD headers
        httpAgent.addheader("Accept", "*/*")
        httpAgent.addheader("Origin", "https://android.tv.twitch.tv")
        httpAgent.addheader("Referer", "https://android.tv.twitch.tv/")
        httpAgent.addheader("User-Agent", "Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) 85.0.4183.93/6.0 TV Safari/537.36")
        httpAgent.addheader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")

        ' Add low latency specific headers if enabled
        latencyPreference = get_user_setting("preferred.latency", "low")
        if isLiveContent and latencyPreference = "low"
            httpAgent.addheader("Cache-Control", "no-cache")
            httpAgent.addheader("Connection", "keep-alive")
        end if
    end if

    m.video.setHttpAgent(httpAgent)

    ' Configure video for appropriate latency mode
    configureVideoForLatency(m.video, isLiveContent)

    m.video.notificationInterval = 1
    m.video.observeField("toggleChat", "onToggleChat")
    m.video.observeField("QualityChangeRequestFlag", "onQualityChangeRequested")

    ' Only add position tracking for debugging, don't use for seeking
    m.video.observeField("position", "onPositionChanged")

    ' Enhanced error handling for live streams and clips
    if isLiveContent or isClipContent
        m.video.observeField("state", "onVideoStateChange")
        m.video.observeField("errorCode", "onVideoError")

        if isLiveContent
            m.video.retryInterval = 3000 ' Retry every 3 seconds on error
            m.video.maxRetries = 15 ' Maximum retry attempts
            ' Disable automatic live edge seeking - let the player handle it
            m.disableAutoSeek = true
            ' Only track duration for logging
            m.video.observeField("duration", "onDurationChanged")
        else if isClipContent
            ' Clip-specific error handling
            m.video.retryInterval = 2000
            m.video.maxRetries = 5
            ? "[VideoPlayer] Configured clip error handling"
        end if
    end if

    videoBookmarks = get_user_setting("VideoBookmarks", "")
    m.video.video_type = m.top.contentRequested.contentType
    m.video.video_id = m.top.contentRequested.contentId

    if videoBookmarks <> ""
        m.video.videoBookmarks = ParseJSON(videoBookmarks)
    else
        m.video.videoBookmarks = {}
    end if

    ? "Quality Selection: "; m.top.content
    ? "Latency Mode: "; get_user_setting("preferred.latency", "low")

    content = m.top.content
    if content <> invalid then
        ' Set stream error handling based on content type
        if isLiveContent
            content.ignoreStreamErrors = false
            content.switchingStrategy = "full-adaptation"
        else if isClipContent
            ' For clips, be more permissive with errors but try to handle auth issues
            content.ignoreStreamErrors = true
            content.switchingStrategy = "no-adaptation"

            ' Set additional clip-specific properties
            content.streamFormat = "mp4"
            content.enableTrickPlay = false

            ? "[VideoPlayer] Configured content for clip playback"
        end if

        m.video.content = content

        if content.streamerProfileImageUrl <> invalid
            m.video.channelAvatar = content.streamerProfileImageUrl
        end if
        if content.streamerDisplayName <> invalid
            m.video.channelUsername = content.streamerDisplayName
        end if
        if content.contentTitle <> invalid
            m.video.videoTitle = content.contentTitle
        end if

        m.video.visible = false

        if m.video.video_id <> invalid and m.top.contentRequested.contentType <> "LIVE"
            ? "video id is valid: "; m.video.video_id
            if m.video.videoBookmarks.DoesExist(m.video.video_id)
                ? "Jump To Position From Bookmarks > " m.video.videoBookmarks[m.video.video_id]
                m.video.seek = Val(m.video.videoBookmarks[m.video.video_id])
            end if
        end if

        m.PlayerTask = CreateObject("roSGNode", "PlayerTask")
        m.PlayerTask.observeField("state", "taskStateChanged")
        m.PlayerTask.video = m.video
        m.PlayerTask.control = "RUN"

        ' Only initialize chat for live content
        if isLiveContent
            initChat()
        end if
    end if
end sub

sub onPositionChanged()
    ' Only log position for debugging - don't trigger seeks
    if m.top.contentRequested.contentType = "LIVE"
        latencyPreference = get_user_setting("preferred.latency", "low")
        if latencyPreference = "low"
            currentPos = m.video.position
            duration = m.video.duration
            if duration > 0 and currentPos > 0
                liveEdgeOffset = duration - currentPos
                ' Only log occasionally to reduce spam
                if liveEdgeOffset > 10 and (liveEdgeOffset mod 5) < 1
                    ? "[VideoPlayer] Live edge offset: "; liveEdgeOffset; " seconds"
                end if
            end if
        end if
    end if
end sub

sub onDurationChanged()
    ' Track duration changes for live streams
    if m.top.contentRequested.contentType = "LIVE"
        ? "[VideoPlayer] Live stream duration updated: "; m.video.duration
    end if
end sub

sub onVideoStateChange()
    videoState = m.video.state
    ? "[VideoPlayer] Video state changed to: "; videoState

    ' Handle specific states for better low latency performance
    if videoState = "buffering"
        latencyPreference = get_user_setting("preferred.latency", "low")
        if latencyPreference = "low" and m.top.contentRequested.contentType = "LIVE"
            ? "[VideoPlayer] Low latency buffering detected"
        end if
    else if videoState = "playing"
        ? "[VideoPlayer] Playback started successfully"
    else if videoState = "error"
        ? "[VideoPlayer] Video error detected, will attempt recovery"

        ' Special handling for clip authentication errors
        if m.top.contentRequested.contentType = "CLIP"
            ? "[VideoPlayer] Clip playback error - may need different URL or auth"
        end if
    end if
end sub

sub onVideoError()
    errorCode = m.video.errorCode
    ? "[VideoPlayer] Video error code: "; errorCode

    ' Handle specific errors that might occur with clips and low latency streams
    if errorCode <> invalid
        if errorCode = -3 or errorCode = -5 ' Network or timeout errors
            ? "[VideoPlayer] Network error detected, may retry with different settings"
        else if errorCode = -1 ' Authentication error
            if m.top.contentRequested.contentType = "CLIP"
                ? "[VideoPlayer] Clip authentication error - URL may be expired or require different auth"
            end if
        end if
    end if
end sub

sub exitPlayer()
    print "Player: exitPlayer()"

    if m.video <> invalid
        m.video.control = "stop"
        m.video.visible = false
    end if
    m.PlayerTask = invalid
    'signal upwards that we are done
    ? "Allow Break?: "; m.allowBreak
    if m.allowBreak
        m.top.state = "done"
        m.top.backpressed = true
    end if
end sub

function onKeyEvent(key, press) as boolean
    if press
        ? "[VideoPlayer] Key Event: "; key
        if key = "back" then
            'handle Back button, by exiting play
            if m.chatWindow <> invalid
                m.chatWindow.callFunc("stopJobs")
            end if
            exitPlayer()
            m.top.backpressed = true
            return true
        end if
    end if
end function

sub init()
    ' m.video.observeField("back", "onvideoBack")
    m.chatWindow = m.top.findNode("chat")
    if m.chatWindow <> invalid
        m.chatWindow.fontSize = get_user_setting("ChatFontSize")
        m.chatWindow.observeField("visible", "onChatVisibilityChange")
    end if
    m.allowBreak = true
end sub

sub onToggleChat()
    ? "Main Scene > onToggleChat"
    if m.video.toggleChat = true
        if m.chatWindow <> invalid
            m.chatWindow.visible = not m.chatWindow.visible
            m.video.chatIsVisible = m.chatWindow.visible
        end if
        m.video.toggleChat = false
    end if
end sub

sub onChatVisibilityChange()
    if m.chatWindow <> invalid
        if m.chatWindow.visible
            m.chatWindow.width = 320
            m.video.width = 960
            m.video.height = 720
        else
            m.video.width = 0
            m.video.height = 0
        end if
    end if
end sub

function checkBookmarks()
    ' ? "Check the bookmark"
    if m.video.video_id <> invalid
        ' ?"video id is valid: "; m.video.video_id
        if m.video.videoBookmarks.DoesExist(m.video.video_id)
            ' ? "Jump To Position From Bookmarks > " m.video.videoBookmarks[m.video.video_id]
            m.video.seek = Val(m.video.videoBookmarks[m.video.video_id])
        end if
    end if
end function