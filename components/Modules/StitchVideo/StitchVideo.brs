function init()
    ' bump
    m.top.enableUI = "false"
    m.top.enableTrickPlay = "false"
    m.progressBar = m.top.findNode("progressBar")
    m.progressBar.visible = false
    m.progressBarBase = m.top.findNode("progressBarBase")
    m.progressBarProgress = m.top.findNode("progressBarProgress")
    m.progressDot = m.top.findNode("progressDot")
    m.timeProgress = m.top.findNode("timeProgress")
    m.timeDuration = m.top.findNode("timeDuration")
    m.controlButton = m.top.findNode("controlButton")

    m.messagesButton = m.top.findNode("messagesButton")
    m.qualitySelectButton = m.top.findNode("qualitySelectButton")
    m.QualityDialog = m.top.findNode("QualityDialog")
    m.glow = m.top.findNode("bg-glow")

    ' Low latency indicator
    m.lowLatencyIndicator = m.top.findNode("lowLatencyIndicator")
    m.latencyModeLabel = m.top.findNode("latencyModeLabel")

    m.currentProgressBarState = 0
    m.currentPositionSeconds = 0
    m.currentPositionUpdated = false
    m.thumbnails = m.top.findNode("thumbnails")
    m.thumbnailImage = m.top.findNode("thumbnailImage")

    m.videoTitle = m.top.findNode("videoTitle")
    m.channelUsername = m.top.findNode("channelUsername")
    m.avatar = m.top.findNode("avatar")

    m.focusedTimeSlot = 0
    m.focusedTimeButton = 0
    m.progressBarFocused = false

    ' Initialize latency monitoring
    m.latencyPreference = get_user_setting("preferred.latency", "low")
    m.isLowLatencyMode = (m.latencyPreference = "low")
    m.lastBufferCheck = 0
    m.bufferHealthTimer = createObject("roSGNode", "Timer")
    m.bufferHealthTimer.observeField("fire", "onBufferHealthCheck")
    m.bufferHealthTimer.repeat = true
    m.bufferHealthTimer.duration = "2"

    ' Stream quality monitoring
    m.qualityChangeCount = 0
    m.lastQualityChange = 0
    m.streamStartTime = createObject("roDateTime").AsSeconds()

    ' Live edge tracking for progress bar accuracy
    m.liveEdgeOffset = 0
    m.lastLiveEdgeUpdate = 0
    m.progressUpdateTimer = createObject("roSGNode", "Timer")
    m.progressUpdateTimer.observeField("fire", "onProgressUpdate")
    m.progressUpdateTimer.repeat = true
    m.progressUpdateTimer.duration = "0.5" ' Update twice per second for smooth progress

    ' Buffer status tracking
    m.lastBufferPercentage = 0
    m.bufferStableCount = 0

    m.top.observeField("position", "watcher")
    m.top.observeField("state", "onvideoStateChange")
    m.top.observeField("chatIsVisible", "onChatVisibilityChange")
    m.top.observeField("bufferingStatus", "onBufferingStatusChange")
    m.top.observeField("streamInfo", "onStreamInfoChange")
    m.top.observeField("duration", "onDurationChange")

    m.uiResolution = createObject("roDeviceInfo").GetUIResolution()
    m.uiResolutionWidth = m.uiResolution.width
    if m.uiResolutionWidth = 1920
        m.thumbnails.clippingRect = [0, 0, 146.66, 82.66]
    end if

    deviceInfo = CreateObject("roDeviceInfo")
    uiResolutionWidth = deviceInfo.GetUIResolution().width
    m.sec = createObject("roRegistrySection", "VideoSettings")

    m.fadeAwayTimer = createObject("roSGNode", "Timer")
    m.fadeAwayTimer.observeField("fire", "onFadeAway")
    m.fadeAwayTimer.repeat = false
    m.fadeAwayTimer.duration = "8"
    m.fadeAwayTimer.control = "stop"

    m.buttonHoldTimer = createObject("roSGNode", "Timer")
    m.buttonHoldTimer.observeField("fire", "onButtonHold")
    m.buttonHoldTimer.repeat = true
    m.buttonHoldTimer.duration = "0.070"
    m.buttonHoldTimer.control = "stop"

    m.buttonHeld = invalid
    m.scrollInterval = 10
    m.top.streamLayoutMode = 0
    m.buttonFocused = "controlButton"

    ' Initialize latency indicator
    updateLatencyIndicator()

    ? "Check the bookmark"
    ? "[StitchVideo] Initialized with latency mode: "; m.latencyPreference
end function

sub updateLatencyIndicator()
    if m.lowLatencyIndicator <> invalid and m.latencyModeLabel <> invalid
        if m.isLowLatencyMode
            m.lowLatencyIndicator.visible = true
            m.latencyModeLabel.text = "Low Latency"
            m.latencyModeLabel.color = "0xFFFFFF"
        else
            m.lowLatencyIndicator.visible = true
            m.latencyModeLabel.text = "Normal"
            m.latencyModeLabel.color = "0xFFFFFF"
        end if
    end if
end sub

sub onDurationChange()
    ' Track live edge changes for better progress bar accuracy
    if m.top.video_type = "LIVE" and m.isLowLatencyMode
        currentTime = createObject("roDateTime").AsSeconds()
        if (currentTime - m.lastLiveEdgeUpdate) > 1
            m.lastLiveEdgeUpdate = currentTime
            if m.top.duration > 0 and m.top.position > 0
                m.liveEdgeOffset = m.top.duration - m.top.position
                ? "[StitchVideo] Live edge offset updated: "; m.liveEdgeOffset; " seconds"
            end if
        end if
    end if
end sub

sub onProgressUpdate()
    ' Update progress bar more frequently for live streams
    if m.top.video_type = "LIVE" and m.top.state = "playing"
        updateProgressBarDisplay()
    end if
end sub

sub updateProgressBarDisplay()
    ' Enhanced progress bar update for live streams
    if m.top.duration > 0
        currentPos = m.top.position
        duration = m.top.duration

        ' For live streams, adjust display to show relative position
        if m.top.video_type = "LIVE" and m.isLowLatencyMode
            ' Show progress relative to live edge
            if m.liveEdgeOffset > 0
                adjustedDuration = duration
                adjustedPosition = currentPos

                ' Update progress bar to reflect live position
                progressRatio = adjustedPosition / adjustedDuration
                m.progressBarProgress.width = m.progressBarBase.width * progressRatio
                m.progressDot.translation = [m.progressBarBase.width * progressRatio + 33, 77]

                ' Update time displays
                m.timeProgress.text = convertToReadableTimeFormat(adjustedPosition)
                m.timeDuration.text = "LIVE"
            else
                ' Standard progress bar update
                progressRatio = currentPos / duration
                m.progressBarProgress.width = m.progressBarBase.width * progressRatio
                m.progressDot.translation = [m.progressBarBase.width * progressRatio + 33, 77]
                m.timeProgress.text = convertToReadableTimeFormat(currentPos)
                m.timeDuration.text = convertToReadableTimeFormat(duration)
            end if
        else
            ' Standard progress bar for VOD or normal latency
            progressRatio = currentPos / duration
            m.progressBarProgress.width = m.progressBarBase.width * progressRatio
            m.progressDot.translation = [m.progressBarBase.width * progressRatio + 33, 77]
            m.timeProgress.text = convertToReadableTimeFormat(currentPos)
            m.timeDuration.text = convertToReadableTimeFormat(duration)
        end if
    end if
end sub

sub onBufferHealthCheck()
    ' Monitor buffer health for low latency streams
    if m.isLowLatencyMode and m.top.state = "playing"
        currentTime = createObject("roDateTime").AsSeconds()

        ' Check if we're experiencing frequent buffering
        if m.top.bufferingStatus <> invalid
            bufferPercent = m.top.bufferingStatus.percentage

            ' Track buffer stability
            if bufferPercent = m.lastBufferPercentage
                m.bufferStableCount = m.bufferStableCount + 1
            else
                m.bufferStableCount = 0
                m.lastBufferPercentage = bufferPercent
            end if

            if bufferPercent < 20 and (currentTime - m.lastBufferCheck) > 5
                ? "[StitchVideo] Low buffer detected in low latency mode: "; bufferPercent; "%"
                m.lastBufferCheck = currentTime

                ' Adaptive response to low buffer
                if m.qualityChangeCount < 3 and m.bufferStableCount < 5
                    ? "[StitchVideo] Consider quality adaptation for better low latency performance"
                end if
            end if
        end if
    end if
end sub

sub onBufferingStatusChange()
    if m.top.bufferingStatus <> invalid
        bufferInfo = m.top.bufferingStatus
        if m.isLowLatencyMode
            targetText = "invalid"
            if bufferInfo.targetMs <> invalid
                targetText = bufferInfo.targetMs.toStr()
            end if
            ? "[StitchVideo] Low Latency Buffer Status - Percentage: "; bufferInfo.percentage; "%, Target: "; targetText; "ms"

            ' Show buffer status in low latency mode for debugging
            if bufferInfo.percentage < 10
                ? "[StitchVideo] WARNING: Very low buffer in low latency mode"
            end if
        end if
    end if
end sub

sub onStreamInfoChange()
    if m.top.streamInfo <> invalid
        streamInfo = m.top.streamInfo
        bitrateText = "invalid"
        resolutionText = "invalid"

        if streamInfo.bitrate <> invalid
            bitrateText = streamInfo.bitrate.toStr()
        end if
        if streamInfo.resolution <> invalid
            resolutionText = streamInfo.resolution.toStr()
        end if

        ? "[StitchVideo] Stream Info Updated - Bitrate: "; bitrateText; ", Resolution: "; resolutionText

        ' Track quality changes for low latency optimization
        currentTime = createObject("roDateTime").AsSeconds()
        if (currentTime - m.lastQualityChange) > 10
            m.qualityChangeCount += 1
            m.lastQualityChange = currentTime

            if m.isLowLatencyMode and m.qualityChangeCount > 5
                ? "[StitchVideo] Frequent quality changes detected in low latency mode"
            end if
        end if
    end if
end sub

function watcher()
    m.currentPositionSeconds = m.top.position

    ' Use enhanced progress bar update for live streams
    if m.top.video_type = "LIVE"
        updateProgressBarDisplay()
    else
        ' Standard update for VOD
        m.timeProgress.text = convertToReadableTimeFormat(m.currentPositionSeconds)
        m.timeDuration.text = convertToReadableTimeFormat(m.top.duration)
        if m.top.duration <> 0
            m.progressBarProgress.width = m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration)
            m.progressDot.translation = [m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration) + 33, 77]
        end if
    end if

    checker = m.top.position mod 20
    if checker = 0
        saveVideoBookmark()
    end if

    ' Start buffer monitoring for live streams
    if m.top.video_type = "LIVE" and m.bufferHealthTimer.control <> "start"
        m.bufferHealthTimer.control = "start"
    end if

    ' Start progress update timer for live streams
    if m.top.video_type = "LIVE" and m.progressUpdateTimer.control <> "start"
        m.progressUpdateTimer.control = "start"
    end if
end function

function resetProgressBar()
    m.controlButton.blendColor = "0xFFFFFFFF"
    m.messagesButton.blendColor = "0xFFFFFFFF"
    m.qualitySelectButton.blendColor = "0xFFFFFFFF"
    m.currentProgressBarState = 0
    m.thumbnailImage.visible = false
    m.progressBar.visible = false
end function

sub onQualityButtonSelect()
    ? "QualityButtonSelect"
    m.QualityDialog.visible = false
    m.QualityDialog.setFocus(false)
    resetProgressBar()
    m.progressBar.getParent().setFocus(true)
    m.top.qualityChangeRequest = m.QualityDialog.buttonSelected
    m.top.qualityChangeRequestFlag = true

    ' Log quality change for low latency monitoring
    if m.isLowLatencyMode
        ? "[StitchVideo] Manual quality change in low latency mode to: "; m.QualityDialog.buttonSelected
    end if
end sub

sub onQualitySelectButtonPressed()
    if m.top.qualityOptions <> invalid
        m.QualityDialog.title = "Please Choose Your Video Quality"
        if m.top.content.qualityId <> invalid
            activeText = "Active: " + m.top.content.qualityId
            if m.isLowLatencyMode
                activeText += " (Low Latency)"
            end if
            m.QualityDialog.message = [activeText]
        end if
        m.QualityDialog.buttons = m.top.qualityOptions
        m.QualityDialog.observeFieldScoped("buttonSelected", "onQualityButtonSelect")
        m.QualityDialog.visible = true
        m.lastFocusedchild = m.top.focusedChild
        m.QualityDialog.setFocus(true)
    end if
end sub

sub onChatVisibilityChange()
    if m.top.chatIsVisible
        ' Adjust layout when chat is visible
        m.progressBarBase.width = 960
        m.glow.translation = [552, 32]
        m.qualitySelectButton.translation = [408, 51]
        m.controlButton.translation = [494, 53]
        m.messagesButton.translation = [570, 52]
        m.timeDuration.translation = [958, 61]

        ' Position latency indicator when chat is visible
        if m.lowLatencyIndicator <> invalid
            m.lowLatencyIndicator.translation = [850, 10]
        end if
    else
        ' Full width layout when chat is hidden
        m.progressBarBase.width = 1200
        m.glow.translation = [692, 32]
        m.qualitySelectButton.translation = [548, 51]
        m.controlButton.translation = [634, 53]
        m.messagesButton.translation = [710, 52]
        m.timeDuration.translation = [1198, 61]

        ' Position latency indicator when chat is hidden
        if m.lowLatencyIndicator <> invalid
            m.lowLatencyIndicator.translation = [1100, 10]
        end if
    end if
end sub

sub onVideoStateChange()
    if m.top.state = "playing"
        m.top.setFocus(true)
        m.controlButton.uri = "pkg:/images/pause.png"

        ' Start monitoring for live streams
        if m.top.video_type = "LIVE"
            m.bufferHealthTimer.control = "start"
            m.progressUpdateTimer.control = "start"
        end if

        ? "[StitchVideo] Playback started in "; m.latencyPreference; " latency mode"
    else if m.top.state = "paused"
        m.controlButton.uri = "pkg:/images/play.png"
        m.bufferHealthTimer.control = "stop"
        m.progressUpdateTimer.control = "stop"
    else if m.top.state = "buffering"
        if m.isLowLatencyMode
            ? "[StitchVideo] Buffering in low latency mode"
        end if
    else if m.top.state = "error"
        ? "[StitchVideo] Video error in "; m.latencyPreference; " latency mode"
        m.bufferHealthTimer.control = "stop"
        m.progressUpdateTimer.control = "stop"

        ' Could implement error recovery specific to low latency here
        if m.isLowLatencyMode
            ? "[StitchVideo] Error recovery for low latency stream"
        end if
    else
        m.controlButton.uri = "pkg:/images/play.png"
        m.bufferHealthTimer.control = "stop"
        m.progressUpdateTimer.control = "stop"
    end if
end sub

function hideOverlay()
    m.controlButton.blendColor = "0xFFFFFFFF"
    m.messagesButton.blendColor = "0xFFFFFFFF"
    m.qualitySelectButton.blendColor = "0xFFFFFFFF"
    m.currentProgressBarState = 0
    m.thumbnailImage.visible = false
    m.progressBar.visible = false

    ' Keep latency indicator visible but dimmed
    if m.lowLatencyIndicator <> invalid
        m.lowLatencyIndicator.opacity = 0.5
    end if
end function

function showOverlay()
    focusButton(m.controlButton)
    m.thumbnailImage.visible = true
    m.progressBar.visible = true
    m.currentProgressBarState = 1

    ' Make latency indicator fully visible
    if m.lowLatencyIndicator <> invalid
        m.lowLatencyIndicator.opacity = 1.0
    end if
end function

sub onFadeAway()
    if not m.QualityDialog.visible
        hideOverlay()
    end if
end sub

sub onButtonHold()
    if m.buttonHeld <> invalid
        if m.buttonHeld = "right"
            m.currentPositionSeconds += m.scrollInterval
            m.progressBarProgress.width = m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration)
            m.progressDot.translation = [m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration) + 33, 77]
            if m.currentPositionSeconds > m.top.duration
                m.currentPositionSeconds = m.top.duration
            end if
            if m.top.thumbnailInfo <> invalid
                if m.top.thumbnailInfo.width <> invalid
                    if m.progressBarProgress.width + m.top.thumbnailInfo.width / 2 <= m.progressBarBase.width
                        if m.progressBarProgress.width - m.top.thumbnailInfo.width / 2 >= 0
                            m.thumbnails.translation = [m.progressBarProgress.width - m.top.thumbnailInfo.width / 2, -150]
                        else
                            m.thumbnails.translation = [0, -150]
                        end if
                    else
                        m.thumbnails.translation = [m.progressBarBase.width - m.top.thumbnailInfo.width, -150]
                    end if
                end if
            end if
        else if m.buttonHeld = "left"
            m.currentPositionSeconds -= m.scrollInterval
            m.progressBarProgress.width = m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration)
            m.progressDot.translation = [m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration) + 33, 77]
            if m.currentPositionSeconds < 0
                m.currentPositionSeconds = 0
            end if
            if m.top.thumbnailInfo <> invalid
                if m.top.thumbnailInfo.width <> invalid
                    if m.progressBarProgress.width - m.top.thumbnailInfo.width / 2 >= 0
                        if m.progressBarProgress.width + m.top.thumbnailInfo.width / 2 <= m.progressBarBase.width
                            m.thumbnails.translation = [m.progressBarProgress.width - m.top.thumbnailInfo.width / 2, -150]
                        else
                            m.thumbnails.translation = [m.progressBarBase.width - m.top.thumbnailInfo.width, -150]
                        end if
                    else
                        m.thumbnails.translation = [0, -150]
                    end if
                end if
                if m.top.thumbnailInfo.width <> invalid
                    showThumbnail()
                end if
            end if
        end if
    end if
    m.timeProgress.text = convertToReadableTimeFormat(m.currentPositionSeconds)

    ' Show "LIVE" for live streams instead of duration
    if m.top.video_type = "LIVE"
        m.timeDuration.text = "LIVE"
    else
        m.timeDuration.text = convertToReadableTimeFormat(m.top.duration)
    end if

    m.scrollInterval += 10
end sub

function convertToReadableTimeFormat(time) as string
    time = Int(time)
    if time < 3600
        seconds = Int((time mod 60))
        if seconds < 10
            seconds = "0" + Int((time mod 60)).ToStr()
        else
            seconds = seconds.ToStr()
        end if
        return Int((time / 60)).ToStr() + ":" + seconds
    else
        hours = Int(time / 3600)
        minutes = Int((time mod 3600) / 60)
        seconds = Int((time mod 3600) mod 60)
        if seconds < 10
            seconds = "0" + seconds.ToStr()
        else
            seconds = seconds.ToStr()
        end if
        if minutes < 10
            minutes = "0" + minutes.ToStr()
        else
            minutes = minutes.ToStr()
        end if
        return hours.ToStr() + ":" + minutes + ":" + seconds
    end if
end function

sub onVideoPositionChange()
    updateProgressBarDisplay()
end sub

sub showThumbnail()
    if m.top.thumbnailInfo <> invalid and m.top.thumbnailInfo.width <> invalid
        thumbnailsPerPart = Int(m.top.thumbnailInfo.count / m.top.thumbnailInfo.thumbnail_parts.Count())
        thumbnailPosOverall = Int(m.currentPositionSeconds / m.top.thumbnailInfo.interval)
        thumbnailPosCurrent = thumbnailPosOverall mod thumbnailsPerPart
        thumbnailRow = Int(thumbnailPosCurrent / m.top.thumbnailInfo.cols)
        thumbnailCol = Int(thumbnailPosCurrent mod m.top.thumbnailInfo.cols)
        if m.uiResolutionWidth = 1280
            m.thumbnailImage.translation = [-thumbnailCol * m.top.thumbnailInfo.width, -thumbnailRow * m.top.thumbnailInfo.height]
        else
            m.thumbnailImage.translation = [(-thumbnailCol * m.top.thumbnailInfo.width) * 0.66, (-thumbnailRow * m.top.thumbnailInfo.height) * 0.66]
        end if
        if m.top.thumbnailInfo.info_url <> invalid and m.top.thumbnailInfo.thumbnail_parts[Int(thumbnailPosOverall / thumbnailsPerPart)] <> invalid
            m.thumbnailImage.uri = m.top.thumbnailInfo.info_url + m.top.thumbnailInfo.thumbnail_parts[Int(thumbnailPosOverall / thumbnailsPerPart)]
        end if
        m.thumbnailImage.visible = true
    end if
end sub

function saveVideoBookmark() as void
    if m.top.video_type = "LIVE" or m.top.video_type = "VOD"
        bookmarkPosition = Int(m.top.position)
        if m.top.video_type = "LIVE" and m.top?.content?.createdAt <> invalid
            secondsSincePublished = createObject("roDateTime")
            secondsSincePublished.FromISO8601String(m.top.content.createdAt.toStr())
            currentTime = createObject("roDateTime").AsSeconds()
            bookmarkPosition = currentTime - secondsSincePublished.AsSeconds()
        end if
        if get_user_setting("id", invalid) <> invalid
            if m.bookmarkTask <> invalid
                m.bookmarkTask = invalid
            end if
            m.bookmarkTask = createObject("roSGNode", "TwitchApiTask")
            m.bookmarkTask.functionname = "updateUserViewedVideo"
            m.bookmarkTask.request = {
                "userId": get_user_setting("id")
                "position": bookmarkPosition
                "videoId": m.top.video_id
                "videoType": m.top.video_type 'LIVE or VOD
            }
            m.bookmarkTask.control = "run"
        else
            if m.top.duration >= 900
                videoBookmarks = "{"

                tempBookmarks = m.top.videoBookmarks
                if m.top.video_id <> invalid
                    bookmarkAlreadyExists = tempBookmarks.DoesExist(m.top.video_id)
                    tempBookmarks[m.top.video_id] = Int(m.top.position).ToStr()
                else
                    bookmarkAlreadyExists = false
                end if

                if tempBookmarks.Count() < 100
                    first = true
                    for each item in tempBookmarks.Items()
                        if not first
                            videoBookmarks += ","
                        end if
                        videoBookmarks += chr(34) + item.key + chr(34) + " : " + chr(34) + item.value + chr(34)
                        first = false
                    end for
                else
                    skip = true
                    first = true
                    for each item in tempBookmarks.Items()
                        if not skip
                            if not first
                                videoBookmarks += ","
                            end if
                            videoBookmarks += chr(34) + item.key + chr(34) + " : " + chr(34) + item.value + chr(34)
                            first = false
                        end if
                        skip = false
                    end for
                end if

                if m.top.thumbnailInfo <> invalid and bookmarkAlreadyExists = false
                    videoBookmarks += "," + chr(34) + m.top.video_id.ToStr() + chr(34) + " : " + chr(34) + Int(m.top.position).ToStr() + chr(34) + "}"
                else
                    videoBookmarks += "}"
                end if

                m.top.videoBookmarks = tempBookmarks
                set_user_setting("VideoBookmarks", videoBookmarks)
            end if
        end if
    end if
end function

function resetButtonState()
    m.messagesButton.blendColor = "0xFFFFFFFF"
    m.qualitySelectButton.blendColor = "0xFFFFFFFF"
    m.controlButton.blendColor = "0xFFFFFFFF"
end function

function focusButton(button)
    resetButtonState()
    w = button.width
    h = button.height
    m.glow.translation = [button.translation[0] - 30 + w / 2, button.translation[1] - 30 + h / 2]
    button.blendColor = "0xBD00FFFF"
    m.buttonFocused = button.id
    m.currentProgressBarState = 1
    return true
end function

function selectButton()
    if m.buttonFocused = "controlButton"
        togglePlayPause()
        return true
    end if
    if m.buttonFocused = "messagesButton"
        m.top.toggleChat = true
        m.top.streamLayoutMode = (m.top.streamLayoutMode + 1) mod 3
        return true
    end if
    if m.buttonFocused = "qualitySelectButton"
        onQualitySelectButtonPressed()
        return true
    end if
end function

function togglePlayPause()
    if m.currentProgressBarState = 2
        m.top.seek = m.currentPositionSeconds
        m.currentPositionUpdated = false
        m.currentProgressBarState = 1
    else
        if m.top.state = "paused"
            m.top.control = "resume"
            m.currentPositionUpdated = false
        else
            m.top.control = "pause"
        end if
    end if
end function

function onKeyEvent(key, press) as boolean
    ? "[StitchVideo] KeyEvent: "; key; " "; press
    if press
        if key <> "back"
            if m.progressBar.visible = false
                ? "show called"
                showOverlay()
            end if
        end if
        m.fadeAwayTimer.control = "stop"
        m.fadeAwayTimer.control = "start"
        if key = "right"
            ? "focused button: "; m.buttonFocused
            if m.buttonFocused = "controlButton"
                focusButton(m.messagesButton)
            else if m.buttonFocused = "qualitySelectButton"
                focusButton(m.controlButton)
            else if m.buttonFocused = "messagesButton"
                focusButton(m.qualitySelectButton)
            end if
            return true
        else if key = "left"
            if m.buttonFocused = "controlButton"
                focusButton(m.qualitySelectButton)
            else if m.buttonFocused = "qualitySelectButton"
                focusButton(m.messagesButton)
            else if m.buttonFocused = "messagesButton"
                focusButton(m.controlButton)
            end if
            return true
        else if key = "down"
            hideOverlay()
            return true
        else if key = "back"
            if m.progressBar.visible
                hideOverlay()
                return true
            end if
        else if key = "OK"
            selectButton()
        else if key = "fastforward"
            ' Disable fast forward for live low latency streams
            if m.top.video_type = "LIVE" and m.isLowLatencyMode
                ? "[StitchVideo] Fast forward disabled for low latency live streams"
                return true
            end if

            focusButton(m.controlButton)
            m.currentProgressBarState = 2
            if m.currentPositionUpdated = false
                m.currentPositionSeconds = m.top.position
                m.currentPositionUpdated = true
                m.top.control = "pause"
            end if
            m.currentPositionSeconds += 10
            if m.currentPositionSeconds > m.top.duration
                m.currentPositionSeconds = m.top.duration
            end if
            m.progressBarProgress.width = m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration)
            m.progressDot.translation = [m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration) + 33, 77]
            if m.top.thumbnailInfo <> invalid and m.top.thumbnailInfo.width <> invalid
                if m.progressBarProgress.width + m.top.thumbnailInfo.width / 2 <= m.progressBarBase.width
                    if m.progressBarProgress.width - m.top.thumbnailInfo.width / 2 >= 0
                        m.thumbnails.translation = [m.progressBarProgress.width - m.top.thumbnailInfo.width / 2, -150]
                    else
                        m.thumbnails.translation = [0, -150]
                    end if
                else
                    m.thumbnails.translation = [m.progressBarBase.width - m.top.thumbnailInfo.width, -150]
                end if

                m.timeProgress.text = convertToReadableTimeFormat(m.currentPositionSeconds)
                if m.top.video_type = "LIVE"
                    m.timeDuration.text = "LIVE"
                else
                    m.timeDuration.text = convertToReadableTimeFormat(m.top.duration)
                end if
                if m.top.thumbnailInfo.width <> invalid
                    showThumbnail()
                end if
            end if
            m.buttonHeld = "right"
            m.buttonHoldTimer.control = "start"
        else if key = "rewind"
            ' Disable rewind for live low latency streams
            if m.top.video_type = "LIVE" and m.isLowLatencyMode
                ? "[StitchVideo] Rewind disabled for low latency live streams"
                return true
            end if

            m.progressBar.visible = true
            focusButton(m.controlButton)
            m.currentProgressBarState = 2
            if m.currentPositionUpdated = false
                m.currentPositionSeconds = m.top.position
                m.currentPositionUpdated = true
                m.top.control = "pause"
            end if
            m.currentPositionSeconds -= 10
            if m.currentPositionSeconds < 0
                m.currentPositionSeconds = 0
            end if
            if m.top.thumbnailInfo <> invalid and m.top.thumbnailInfo.width <> invalid
                if m.progressBarProgress.width - m.top.thumbnailInfo.width / 2 >= 0
                    if m.progressBarProgress.width + m.top.thumbnailInfo.width / 2 <= m.progressBarBase.width
                        m.thumbnails.translation = [m.progressBarProgress.width - m.top.thumbnailInfo.width / 2, -150]
                    else
                        m.thumbnails.translation = [m.progressBarBase.width - m.top.thumbnailInfo.width, -150]
                    end if
                else
                    m.thumbnails.translation = [0, -150]
                end if

                m.progressBarProgress.width = m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration)
                m.progressDot.translation = [m.progressBarBase.width * (m.currentPositionSeconds / m.top.duration) + 33, 77]
                m.timeProgress.text = convertToReadableTimeFormat(m.currentPositionSeconds)
                if m.top.video_type = "LIVE"
                    m.timeDuration.text = "LIVE"
                else
                    m.timeDuration.text = convertToReadableTimeFormat(m.top.duration)
                end if
                if m.top.thumbnailInfo.width <> invalid
                    showThumbnail()
                end if
            end if
            m.buttonHeld = "left"
            m.buttonHoldTimer.control = "start"
        else if key = "play"
            togglePlayPause()
            return true
        end if
    else if not press
        if key = "rewind" or key = "fastforward"
            m.scrollInterval = 10
            m.buttonHeld = invalid
            m.buttonHoldTimer.control = "stop"
        end if
    end if
end function