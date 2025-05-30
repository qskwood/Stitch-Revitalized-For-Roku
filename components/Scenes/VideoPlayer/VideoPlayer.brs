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
    m.PlayVideo = CreateObject("roSGNode", "GetTwitchContent")
    m.PlayVideo.observeField("response", "OnResponse")
    m.PlayVideo.contentRequested = selectedItem.getFields()
    m.PlayVideo.functionName = "main"
    m.PlayVideo.control = "run"
end function

function onResponse()
    m.top.content = m.PlayVideo.response
    m.top.metadata = m.PlayVideo.metadata
    playContent()
end function

sub taskStateChanged(event as object)
    state = event.GetData()
    if state = "done" or state = "stop"
        exitPlayer()
    end if
end sub

sub controlChanged()
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
    latencyPreference = get_user_setting("preferred.latency", "low")
    isLowLatency = (latencyPreference = "low")

    if video.isSubtype("StitchVideo")
        return
    end if

    if isLive and isLowLatency
        try
            video.enableLowLatencyHLS = true
            video.hlsOptimization = "lowLatency"
            video.enablePartialSegments = true
            video.enablePreloadHints = true
            video.enableBlockingPlaylistReload = true
            video.llhlsMinSegmentCount = 3
            video.llhlsPartHoldBack = 0.3
            video.llhlsRebufferTarget = 0.5
        catch e
        end try

        video.bufferingConfig = {
            initialBufferingMs: 200,
            minBufferMs: 500,
            maxBufferMs: 1500,
            bufferForPlaybackMs: 200,
            bufferForPlaybackAfterRebufferMs: 500,
            rebufferMs: 200
        }

        video.enableDecoderCompatibility = false
        video.maxVideoDecodeResolution = "1080p"

        video.adaptiveBitrateConfig = {
            initialBandwidthBps: 5000000,
            maxInitialBitrate: 8000000,
            minDurationForQualityIncreaseMs: 60000,
            maxDurationForQualityDecreaseMs: 2000,
            minDurationToRetainAfterDiscardMs: 1000,
            bandwidthMeterSlidingWindowMs: 3000
        }
    else if isLive
        video.bufferingConfig = {
            initialBufferingMs: 2000,
            minBufferMs: 5000,
            maxBufferMs: 15000,
            bufferForPlaybackMs: 2000,
            bufferForPlaybackAfterRebufferMs: 5000,
            rebufferMs: 2000
        }

        video.enableDecoderCompatibility = true

        video.adaptiveBitrateConfig = {
            initialBandwidthBps: 3000000,
            maxInitialBitrate: 6000000,
            minDurationForQualityIncreaseMs: 10000,
            maxDurationForQualityDecreaseMs: 25000,
            minDurationToRetainAfterDiscardMs: 5000,
            bandwidthMeterSlidingWindowMs: 10000
        }
    else
        video.bufferingConfig = {
            initialBufferingMs: 3000,
            minBufferMs: 10000,
            maxBufferMs: 30000,
            bufferForPlaybackMs: 3000,
            bufferForPlaybackAfterRebufferMs: 8000,
            rebufferMs: 3000
        }

        video.enableDecoderCompatibility = true
    end if
end sub

sub measureStreamDelay()
    if m.video <> invalid and m.video.content <> invalid
        currentTime = CreateObject("roDateTime").AsSeconds()
        videoPosition = m.video.position

        if m.delayTrackingStartTime = invalid
            m.delayTrackingStartTime = currentTime
            m.delayTrackingStartPosition = videoPosition
            m.lastRealTime = currentTime
            m.lastVideoPosition = videoPosition
            return
        end if

        realTimeElapsed = currentTime - m.lastRealTime
        videoTimeElapsed = videoPosition - m.lastVideoPosition

        if realTimeElapsed > 0
            progressionRate = videoTimeElapsed / realTimeElapsed

            if m.estimatedLiveDelay = invalid then m.estimatedLiveDelay = 25

            if progressionRate < 0.99
                delayIncrease = realTimeElapsed * (1 - progressionRate)
                m.estimatedLiveDelay = m.estimatedLiveDelay + delayIncrease
            else if progressionRate > 1.01
                delayCatchup = realTimeElapsed * (progressionRate - 1)
                m.estimatedLiveDelay = m.estimatedLiveDelay - delayCatchup
            end if

            if m.estimatedLiveDelay < 5 then m.estimatedLiveDelay = 5
            if m.estimatedLiveDelay > 120 then m.estimatedLiveDelay = 120
        end if

        m.lastRealTime = currentTime
        m.lastVideoPosition = videoPosition
    end if
end sub

function FormatSeconds(seconds as integer) as string
    if seconds < 10
        return "0" + seconds.toStr()
    else
        return seconds.toStr()
    end if
end function

sub playContent()
    if m.video <> invalid
        m.video.unobserveField("toggleChat")
        m.video.unobserveField("qualityChangeRequest") ' Fixed to match observeField
        m.video.unobserveField("position")
        m.video.unobserveField("state")
        m.video.unobserveField("errorCode")
        m.video.unobserveField("duration")
        m.video.unobserveField("back")

        m.top.removeChild(m.video)
        m.video = invalid
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

    httpAgent = CreateObject("roHttpAgent")
    httpAgent.setCertificatesFile("common:/certs/ca-bundle.crt")
    httpAgent.InitClientCertificates()
    httpAgent.enableCookies()

    if isClipContent
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
        httpAgent.addheader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")
        httpAgent.addheader("X-Device-Id", CreateObject("roDeviceInfo").GetRandomUUID())
        authToken = get_user_setting("auth_token", "")
        if authToken <> ""
            httpAgent.addheader("Authorization", "Bearer " + authToken)
        end if
    else
        httpAgent.addheader("Accept", "*/*")
        httpAgent.addheader("Origin", "https://android.tv.twitch.tv")
        httpAgent.addheader("Referer", "https://android.tv.twitch.tv/")
        httpAgent.addheader("User-Agent", "Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) 85.0.4183.93/6.0 TV Safari/537.36")
        httpAgent.addheader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")
        latencyPreference = get_user_setting("preferred.latency", "low")
        if isLiveContent and latencyPreference = "low"
            httpAgent.addheader("Cache-Control", "no-cache")
            httpAgent.addheader("Connection", "keep-alive")
            httpAgent.addheader("X-Low-Latency", "1")
            httpAgent.addheader("X-LL-HLS", "true")
            httpAgent.addheader("X-Target-Latency", "2")
        end if
    end if
    m.video.setHttpAgent(httpAgent)

    configureVideoForLatency(m.video, isLiveContent)

    m.video.notificationInterval = 1

    m.video.observeField("toggleChat", "onToggleChat")
    if isLiveContent
        ' FIX: Changed to match unobserveField name
        m.video.observeField("qualityChangeRequest", "onQualityChangeRequested")
    else
        m.video.observeField("back", "onVideoBack")
    end if
    m.video.observeField("position", "onPositionChanged")
    m.video.observeField("state", "onVideoStateChange")
    m.video.observeField("errorCode", "onVideoError")
    m.video.observeField("duration", "onDurationChanged")

    videoBookmarks = get_user_setting("VideoBookmarks", "")
    m.video.video_type = m.top.contentRequested.contentType
    m.video.video_id = m.top.contentRequested.contentId

    if videoBookmarks <> ""
        m.video.videoBookmarks = ParseJSON(videoBookmarks)
    else
        m.video.videoBookmarks = {}
    end if

    contentNodeToPlay = m.top.content
    if contentNodeToPlay <> invalid then
        if isLiveContent
            contentNodeToPlay.ignoreStreamErrors = false

            latencyPreference = get_user_setting("preferred.latency", "low")
            isLowLatencyMode = (latencyPreference = "low")

            currentQualityID = contentNodeToPlay.QualityID
            isAutomaticQuality = (currentQualityID.Instr("Automatic") > -1)

            if isLowLatencyMode and not isAutomaticQuality and currentQualityID <> ""
                contentNodeToPlay.switchingStrategy = "no-adaptation"
            else
                contentNodeToPlay.switchingStrategy = "full-adaptation"
            end if
        else if isClipContent
            contentNodeToPlay.ignoreStreamErrors = true
            contentNodeToPlay.switchingStrategy = "no-adaptation"
            contentNodeToPlay.streamFormat = "mp4"
            contentNodeToPlay.enableTrickPlay = false
        else
            contentNodeToPlay.ignoreStreamErrors = true
            contentNodeToPlay.switchingStrategy = "full-adaptation"
        end if

        m.video.content = contentNodeToPlay

        if contentNodeToPlay.streamerProfileImageUrl <> invalid
            m.video.channelAvatar = contentNodeToPlay.streamerProfileImageUrl
        end if
        if contentNodeToPlay.streamerDisplayName <> invalid
            m.video.channelUsername = contentNodeToPlay.streamerDisplayName
        end if
        if contentNodeToPlay.contentTitle <> invalid
            m.video.videoTitle = contentNodeToPlay.contentTitle
        end if

        m.video.visible = false

        if m.video.video_id <> invalid and m.top.contentRequested.contentType <> "LIVE"
            if m.video.videoBookmarks.DoesExist(m.video.video_id)
                m.video.seek = Val(m.video.videoBookmarks[m.video.video_id])
            end if
        end if

        m.PlayerTask = CreateObject("roSGNode", "PlayerTask")
        m.PlayerTask.observeField("state", "taskStateChanged")
        m.PlayerTask.video = m.video
        m.PlayerTask.control = "RUN"

        if isLiveContent
            initChat()
            m.delayMeasureTimer = createObject("roSGNode", "Timer")
            m.delayMeasureTimer.observeField("fire", "measureStreamDelay")
            m.delayMeasureTimer.repeat = false
            m.delayMeasureTimer.duration = 10
            m.delayMeasureTimer.control = "start"
        end if
    end if
end sub

sub exitPlayer()
    if m.delayMeasureTimer <> invalid
        m.delayMeasureTimer.control = "stop"
        m.delayMeasureTimer = invalid
    end if

    if m.video <> invalid
        m.video.unobserveField("toggleChat")
        if m.video.isSubtype("StitchVideo")
            ' FIX: This now matches the observeField name
            m.video.unobserveField("qualityChangeRequest")
        else if m.video.isSubtype("CustomVideo")
            m.video.unobserveField("back")
        end if
        m.video.unobserveField("position")
        m.video.unobserveField("state")
        m.video.unobserveField("errorCode")
        m.video.unobserveField("duration")

        m.video.control = "stop"
        m.video.visible = false
    end if

    if m.PlayerTask <> invalid
        m.PlayerTask.unobserveField("state")
        m.PlayerTask.control = "stop"
        m.PlayerTask = invalid
    end if

    if m.allowBreak
        m.top.state = "done"
        m.top.backpressed = true
    end if
end sub

function onKeyEvent(key, press) as boolean
    if press
        if key = "back" then
            if m.chatWindow <> invalid and m.chatWindow.visible = true
                m.chatWindow.callFunc("stopJobs")
            end if
            m.allowBreak = true
            exitPlayer()
            return true
        end if
    end if
    return false
end function

sub init()
    m.chatWindow = m.top.findNode("chat")
    if m.chatWindow <> invalid
        m.chatWindow.fontSize = get_user_setting("ChatFontSize")
        m.chatWindow.observeField("visible", "onChatVisibilityChange")
    end if
    m.allowBreak = true

    m.delayTrackingStartTime = invalid
    m.delayTrackingStartPosition = invalid
    m.lastRealTime = invalid
    m.lastVideoPosition = invalid
    m.estimatedLiveDelay = invalid
end sub

sub onToggleChat()
    if m.video.toggleChat = true
        if m.chatWindow <> invalid
            m.chatWindow.visible = not m.chatWindow.visible
            m.video.chatIsVisible = m.chatWindow.visible
        end if
        m.video.toggleChat = false
    end if
end sub

sub onChatVisibilityChange()
    if m.chatWindow <> invalid and m.video <> invalid
        if m.chatWindow.visible
            m.chatWindow.translation = [1280 - 320, 0]
            m.chatWindow.height = 720
            m.chatWindow.width = 320

            m.video.width = 1280 - 320
            m.video.height = 720
            m.video.translation = [0, 0]
            m.video.chatIsVisible = true
        else
            m.video.width = 1280
            m.video.height = 720
            m.video.translation = [0, 0]
            m.video.chatIsVisible = false
        end if
    end if
end sub

sub onPositionChanged()
    if m.video <> invalid and Int(m.video.position) mod 30 = 0
        measureStreamDelay()
    end if
end sub

sub onVideoStateChange()
    if m.video.state = "finished" and m.allowBreak
        exitPlayer()
    else if m.video.state = "error"
    end if
end sub

sub onVideoError()
end sub

sub onDurationChanged()
end sub

sub onVideoBack()
    if m.chatWindow <> invalid and m.chatWindow.visible = true
        m.chatWindow.callFunc("stopJobs")
    end if
    m.allowBreak = true
    exitPlayer()
end sub