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
        ' Low latency configuration for live streams
        video.bufferingConfig = {
            initialBufferingMs: 500,
            minBufferMs: 1000,
            maxBufferMs: 3000,
            bufferForPlaybackMs: 500,
            bufferForPlaybackAfterRebufferMs: 1000,
            rebufferMs: 500
        }

        ' Additional low latency settings
        video.enableDecoderCompatibility = false
        video.maxVideoDecodeResolution = "1080p"

        ' Set adaptive bitrate parameters for low latency
        video.adaptiveBitrateConfig = {
            initialBandwidthBps: 5000000,
            maxInitialBitrate: 8000000,
            minDurationForQualityIncreaseMs: 2000,
            maxDurationForQualityDecreaseMs: 5000,
            minDurationToRetainAfterDiscardMs: 1000,
            bandwidthMeterSlidingWindowMs: 2000
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

    m.video.setHttpAgent(httpAgent)

    ' Configure video for appropriate latency mode
    configureVideoForLatency(m.video, isLiveContent)

    m.video.notificationInterval = 1
    m.video.observeField("toggleChat", "onToggleChat")
    m.video.observeField("QualityChangeRequestFlag", "onQualityChangeRequested")

    ' Enhanced error handling for live streams
    if isLiveContent
        m.video.observeField("state", "onVideoStateChange")
        m.video.observeField("errorCode", "onVideoError")
        m.video.retryInterval = 5000 ' Retry every 5 seconds on error
        m.video.maxRetries = 10 ' Maximum retry attempts
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
    ? "Latency Mode: "; latencyPreference

    content = m.top.content
    if content <> invalid then
        ' Set stream error handling for live content
        if isLiveContent
            content.ignoreStreamErrors = false
            content.switchingStrategy = "full-adaptation"
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

        if m.video.video_id <> invalid
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
        initChat()
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
            ' Could implement additional low latency optimizations here
        end if
    else if videoState = "error"
        ? "[VideoPlayer] Video error detected, will attempt recovery"
    end if
end sub

sub onVideoError()
    errorCode = m.video.errorCode
    ? "[VideoPlayer] Video error code: "; errorCode

    ' Handle specific errors that might occur with low latency streams
    if errorCode <> invalid
        if errorCode = -3 or errorCode = -5 ' Network or timeout errors
            ? "[VideoPlayer] Network error detected, may retry with different settings"
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
            m.chatWindow.callFunc("stopJobs")
            exitPlayer()
            m.top.backpressed = true
            return true
        end if
    end if
end function

sub init()
    ' m.video.observeField("back", "onvideoBack")
    m.chatWindow = m.top.findNode("chat")
    m.chatWindow.fontSize = get_user_setting("ChatFontSize")
    m.chatWindow.observeField("visible", "onChatVisibilityChange")
    m.allowBreak = true
end sub

sub onToggleChat()
    ? "Main Scene > onToggleChat"
    if m.video.toggleChat = true
        m.chatWindow.visible = not m.chatWindow.visible
        m.video.chatIsVisible = m.chatWindow.visible
        m.video.toggleChat = false
    end if
end sub

sub onChatVisibilityChange()
    if m.chatWindow.visible
        m.chatWindow.width = 320
        m.video.width = 960
        m.video.height = 720
    else
        m.video.width = 0
        m.video.height = 0
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