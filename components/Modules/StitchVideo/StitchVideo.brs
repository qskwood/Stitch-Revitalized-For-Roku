function init()
    ' Initialize UI elements
    m.top.enableUI = false
    m.top.enableTrickPlay = false

    ' Control overlay elements
    m.controlOverlay = m.top.findNode("controlOverlay")
    m.controlOverlay.visible = false

    ' Progress bar elements
    m.progressBarBase = m.top.findNode("progressBarBase")
    m.progressBarProgress = m.top.findNode("progressBarProgress")

    ' Control buttons
    m.playPauseGroup = m.top.findNode("playPauseGroup")
    m.chatGroup = m.top.findNode("chatGroup")
    m.qualityGroup = m.top.findNode("qualityGroup")
    m.controlButton = m.top.findNode("controlButton")
    m.messagesButton = m.top.findNode("messagesButton")
    m.qualitySelectButton = m.top.findNode("qualitySelectButton")

    ' Focus backgrounds
    m.playPauseFocus = m.top.findNode("playPauseFocus")
    m.chatFocus = m.top.findNode("chatFocus")
    m.qualityFocus = m.top.findNode("qualityFocus")

    ' Other elements
    m.liveIndicator = m.top.findNode("liveIndicator")
    m.lowLatencyIndicator = m.top.findNode("lowLatencyIndicator")
    m.normalLatencyIndicator = m.top.findNode("normalLatencyIndicator")
    m.latencyModeLabel = m.top.findNode("latencyModeLabel")

    ' Video info
    m.videoTitle = m.top.findNode("videoTitle")
    m.channelUsername = m.top.findNode("channelUsername")
    m.avatar = m.top.findNode("avatar")

    ' Quality dialog
    m.qualityDialog = m.top.findNode("QualityDialog")

    ' State variables
    m.currentFocusedButton = 1 ' 1=play/pause, 2=chat, 3=quality
    m.isOverlayVisible = false
    m.currentPositionSeconds = 0
    m.isLiveStream = true ' StitchVideo is always for live streams

    ' Timers
    m.fadeAwayTimer = createObject("roSGNode", "Timer")
    m.fadeAwayTimer.observeField("fire", "onFadeAway")
    m.fadeAwayTimer.repeat = false
    m.fadeAwayTimer.duration = 5
    m.fadeAwayTimer.control = "stop"

    ' Observers
    m.top.observeField("position", "onPositionChange")
    m.top.observeField("state", "onVideoStateChange")
    m.top.observeField("chatIsVisible", "onChatVisibilityChange")
    m.top.observeField("duration", "onDurationChange")
    m.top.observeField("bufferingStatus", "onBufferingStatusChange")
    m.top.observeField("qualityOptions", "onQualityOptionsChange")
    m.top.observeField("selectedQuality", "onSelectedQualityChange")

    ' Initialize UI
    updateProgressBar()
    setupLiveUI()
    updateLatencyIndicator()

    ? "[StitchVideo] Initialized for live stream"
end function

sub setupLiveUI()
    ' Set up UI specifically for live streams
    m.progressBarProgress.width = m.progressBarBase.width ' Full bar for live

    ' Live indicator is only visible when overlay is shown
    m.liveIndicator.visible = m.isOverlayVisible
end sub

sub updateLatencyIndicator()
    ' Get the user's preferred latency setting
    latencySetting = get_user_setting("preferred.latency", "low")
    isLowLatency = (latencySetting = "low")

    ' Only show latency indicators when overlay is visible
    if m.isOverlayVisible
        if isLowLatency
            m.lowLatencyIndicator.visible = true
            m.normalLatencyIndicator.visible = false
            ? "[StitchVideo] Low latency mode enabled (user setting)"
        else
            m.lowLatencyIndicator.visible = false
            m.normalLatencyIndicator.visible = true
            ? "[StitchVideo] Normal latency mode (user setting)"
        end if
    else
        ' Hide both when overlay is not visible
        m.lowLatencyIndicator.visible = false
        m.normalLatencyIndicator.visible = false
    end if
end sub

sub onPositionChange()
    m.currentPositionSeconds = m.top.position
    ' Live streams don't need position-based updates
end sub

sub onVideoStateChange()
    if m.top.state = "playing"
        m.controlButton.uri = "pkg:/images/pause.png"
    else if m.top.state = "paused"
        m.controlButton.uri = "pkg:/images/play.png"
    else if m.top.state = "buffering"
        ' Could add loading spinner here
        ? "[StitchVideo] Buffering..."
    else if m.top.state = "error"
        ? "[StitchVideo] Video error occurred"
    end if
end sub

sub onChatVisibilityChange()
    ' Adjust layout based on chat visibility
    if m.top.chatIsVisible
        m.progressBarBase.width = 900
        ' Adjust latency indicator position when chat is visible (move further left)
        m.lowLatencyIndicator.translation = [750, 0]
        m.normalLatencyIndicator.translation = [750, 0]
    else
        m.progressBarBase.width = 1160
        ' Reset latency indicator position (bottom right of overlay)
        m.lowLatencyIndicator.translation = [0, 0]
        m.normalLatencyIndicator.translation = [0, 0]
    end if
    updateProgressBar()
end sub

sub onDurationChange()
    updateProgressBar()
end sub

sub onBufferingStatusChange()
    ' Live streams handle buffering differently
    ? "[StitchVideo] Buffering status changed"
end sub

sub onQualityOptionsChange()
    setupQualityDialog()
end sub

sub onSelectedQualityChange()
    setupLiveUI()
    updateLatencyIndicator()
    ? "[StitchVideo] Quality changed to: "; m.top.selectedQuality
end sub

sub setupQualityDialog()
    if m.top.qualityOptions <> invalid and m.top.qualityOptions.count() > 0
        m.qualityDialog.title = "Please Choose Your Video Quality"
        m.qualityDialog.message = "Choose video quality:"

        buttons = []
        for each quality in m.top.qualityOptions
            buttons.push(quality)
        end for
        buttons.push("Cancel")

        m.qualityDialog.buttons = buttons
    end if
end sub

sub onQualityButtonSelect()
    ? "[StitchVideo] Quality dialog button selected: "; m.qualityDialog.buttonSelected

    selectedIndex = m.qualityDialog.buttonSelected
    totalButtons = m.qualityDialog.buttons.count()

    ' Hide dialog first
    m.qualityDialog.visible = false
    m.qualityDialog.setFocus(false)

    ' Check if Cancel was selected (last button)
    if selectedIndex = totalButtons - 1
        ? "[StitchVideo] Cancel selected, no quality change"
    else if selectedIndex >= 0 and selectedIndex < m.top.qualityOptions.count()
        ' Valid quality option selected
        selectedQuality = m.top.qualityOptions[selectedIndex]
        ? "[StitchVideo] Quality selected: "; selectedQuality

        m.top.selectedQuality = selectedQuality
        m.top.QualityChangeRequest = selectedIndex
        m.top.QualityChangeRequestFlag = true

        ' Update latency indicator
        updateLatencyIndicator()
    else
        ? "[StitchVideo] Invalid selection index: "; selectedIndex
    end if

    ' Restore focus to video component
    m.top.setFocus(true)

    ' If overlay is visible, restart fade timer
    if m.isOverlayVisible
        focusButton(m.currentFocusedButton)
        m.fadeAwayTimer.control = "stop"
        m.fadeAwayTimer.control = "start"
    end if
end sub

sub updateProgressBar()
    ' For live streams, always show full progress bar in Twitch purple
    m.progressBarProgress.width = m.progressBarBase.width
end sub

sub showOverlay()
    m.isOverlayVisible = true
    m.controlOverlay.visible = true
    m.liveIndicator.visible = true ' Show LIVE indicator with overlay
    updateLatencyIndicator() ' Update latency indicator visibility
    focusButton(m.currentFocusedButton)

    ' Start fade timer
    m.fadeAwayTimer.control = "stop"
    m.fadeAwayTimer.control = "start"
end sub

sub hideOverlay()
    m.isOverlayVisible = false
    m.controlOverlay.visible = false
    m.liveIndicator.visible = false ' Hide LIVE indicator with overlay
    updateLatencyIndicator() ' Hide latency indicators
    clearAllButtonFocus()
end sub

sub onFadeAway()
    ' Only hide overlay if quality dialog is not visible
    if not m.qualityDialog.visible
        hideOverlay()
    end if
end sub

sub focusButton(buttonIndex)
    clearAllButtonFocus()
    m.currentFocusedButton = buttonIndex

    if buttonIndex = 1 ' Play/Pause
        m.playPauseFocus.visible = true
    else if buttonIndex = 2 ' Chat
        m.chatFocus.visible = true
    else if buttonIndex = 3 ' Quality
        m.qualityFocus.visible = true
    end if
end sub

sub clearAllButtonFocus()
    m.playPauseFocus.visible = false
    m.chatFocus.visible = false
    m.qualityFocus.visible = false
end sub

sub executeButtonAction()
    if m.currentFocusedButton = 1 ' Play/Pause
        togglePlayPause()
    else if m.currentFocusedButton = 2 ' Chat
        m.top.toggleChat = true
        m.top.streamLayoutMode = (m.top.streamLayoutMode + 1) mod 3
    else if m.currentFocusedButton = 3 ' Quality
        showQualityDialog()
    end if
end sub

sub togglePlayPause()
    if m.top.state = "paused"
        m.top.control = "resume"
    else
        m.top.control = "pause"
    end if
end sub

sub showQualityDialog()
    if m.top.qualityOptions <> invalid and m.top.qualityOptions.count() > 0
        ' Stop the fade timer when showing dialog
        m.fadeAwayTimer.control = "stop"

        ' Set up the observer (following original pattern)
        m.qualityDialog.observeFieldScoped("buttonSelected", "onQualityButtonSelect")

        ' Show dialog and give it focus
        m.qualityDialog.visible = true
        m.qualityDialog.setFocus(true)
    else
        ? "[StitchVideo] No quality options available"
    end if
end sub

function convertToReadableTimeFormat(time) as string
    time = Int(time)
    if time < 3600
        minutes = Int(time / 60)
        seconds = Int(time mod 60)
        if seconds < 10
            secondStr = "0" + seconds.toStr()
        else
            secondStr = seconds.toStr()
        end if
        return minutes.toStr() + ":" + secondStr
    else
        hours = Int(time / 3600)
        minutes = Int((time mod 3600) / 60)
        seconds = Int(time mod 60)

        if minutes < 10
            minuteStr = "0" + minutes.toStr()
        else
            minuteStr = minutes.toStr()
        end if

        if seconds < 10
            secondStr = "0" + seconds.toStr()
        else
            secondStr = seconds.toStr()
        end if

        return hours.toStr() + ":" + minuteStr + ":" + secondStr
    end if
end function

function onKeyEvent(key, press) as boolean
    ? "[StitchVideo] KeyEvent: "; key; " "; press

    if press
        ' If quality dialog is visible, only handle back to close it
        if m.qualityDialog.visible
            if key = "back" or key = "down"
                m.qualityDialog.visible = false
                m.qualityDialog.setFocus(false)
                m.top.setFocus(true)

                ' Restart fade timer if overlay is visible
                if m.isOverlayVisible
                    focusButton(m.currentFocusedButton)
                    m.fadeAwayTimer.control = "stop"
                    m.fadeAwayTimer.control = "start"
                end if
                return true
            end if
            ' Let dialog handle all other keys
            return false
        end if

        ' Normal key handling when dialog is not visible
        ' Reset fade timer on any key press (except back when overlay is hidden)
        if key <> "back" or m.isOverlayVisible
            if m.isOverlayVisible
                m.fadeAwayTimer.control = "stop"
                m.fadeAwayTimer.control = "start"
            end if
        end if

        return handleMainKeys(key)
    end if

    return false
end function

function handleMainKeys(key) as boolean
    if key = "up" or key = "OK" or key = "play"
        if not m.isOverlayVisible
            showOverlay()
            return true
        end if
    end if

    if not m.isOverlayVisible
        return false
    end if

    if key = "left"
        ' Live stream navigation: play/pause(1) -> chat(2) -> quality(3)
        if m.currentFocusedButton > 1
            focusButton(m.currentFocusedButton - 1)
        else
            focusButton(3) ' Wrap to quality
        end if
        return true
    else if key = "right"
        ' Live stream navigation: play/pause(1) -> chat(2) -> quality(3)
        if m.currentFocusedButton < 3
            focusButton(m.currentFocusedButton + 1)
        else
            focusButton(1) ' Wrap to play/pause
        end if
        return true
    else if key = "down" or key = "back"
        hideOverlay()
        return true
    else if key = "OK"
        executeButtonAction()
        return true
    else if key = "play"
        togglePlayPause()
        return true
    end if

    return false
end function