sub handleContent()
    m.PlayVideo = CreateObject("roSGNode", "GetTwitchContent")
    m.PlayVideo.observeField("response", "OnResponse")
    m.PlayVideo.contentRequested = m.top.contentRequested.getFields()
    m.PlayVideo.functionName = "main"
    m.PlayVideo.control = "run"
end sub

sub onPlaybackPositionChanged()
    if m.video.currentPlaybackTime < m.video.duration - 10
        m.video.seekToLive()
    end if
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

sub playContent()
    ' Removes the existing video player if it exists
    if m.video <> invalid
        m.top.removeChild(m.video)
    end if

    ' Check if the requested content is LIVE
    if m.top.contentRequested.contentType = "LIVE"
        quality_options = []
        ' Collect available quality options from metadata
        if m.top.metadata <> invalid
            for each quality_option in m.top.metadata
                quality_options.push(quality_option.qualityID)
            end for
        end if

        ' Create a new video player for live content
        m.video = m.top.CreateChild("StitchVideo")
        m.video.qualityOptions = quality_options
        m.video.minBufferTime = 0 ' Set minimal buffer time to reduce latency
        m.video.startRate = 1.0 ' Ensure the video starts at normal playback rate
        m.video.maxRate = 1.0 ' Lock the playback rate to 1.0 to prevent any adjustments
        m.video.minBufferSize = 1000 ' Minimum buffer size in milliseconds
        m.video.maxBufferSize = 3000 ' Maximum buffer size in milliseconds
        m.video.live = true ' Indicate that this is live content

        m.video.playAtLiveEdge = true ' Force playback to stay at the live edge
        m.video.liveEdgeOffset = 0 ' No offset from the live edge

        ' Observe playback position and adjust to stay at live edge
        m.video.observeField("currentPlaybackTime", "onPlaybackPositionChanged")
    else
        ' Create a new video player for non-live content
        m.video = m.top.CreateChild("CustomVideo")
    end if

    ' Set up HTTP agent for video requests
    httpAgent = CreateObject("roHttpAgent")
    httpAgent.setCertificatesFile("common:/certs/ca-bundle.crt")
    httpAgent.InitClientCertificates()
    httpAgent.enableCookies()
    httpAgent.addheader("Accept", "*/*")
    httpAgent.addheader("Origin", "https://android.tv.twitch.tv")
    httpAgent.addheader("Referer", "https://android.tv.twitch.tv/")
    m.video.setHttpAgent(httpAgent)

    m.video.notificationInterval = 1
    m.video.observeField("toggleChat", "onToggleChat")
    m.video.observeField("QualityChangeRequestFlag", "onQualityChangeRequested")

    ' Retrieve and set video bookmarks
    videoBookmarks = get_user_setting("VideoBookmarks", "")
    m.video.video_type = m.top.contentRequested.contentType
    m.video.video_id = m.top.contentRequested.contentId
    if videoBookmarks <> ""
        m.video.videoBookmarks = ParseJSON(videoBookmarks)
    else
        m.video.videoBookmarks = {}
    end if

    ' Log quality selection
    ? "Quality Selection: "; m.top.content
    content = m.top.content
    if content <> invalid then
        m.video.content = content
        ' Set additional video information
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

        ' Set up player task
        m.PlayerTask = CreateObject("roSGNode", "PlayerTask")
        m.PlayerTask.observeField("state", "taskStateChanged")
        m.PlayerTask.video = m.video
        m.video.playstart = 2147483647
        m.PlayerTask.control = "RUN"
        initChat()
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
        ' Additional logic for handling exit
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