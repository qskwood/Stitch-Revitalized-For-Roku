sub init()
    m.validateOauthToken = CreateObject("roSGNode", "TwitchApiTask")
    m.validateOauthToken.observeField("response", "ValidateUserLogin")
    m.validateOauthToken.functionName = "validateOauthToken"
    m.validateOauthToken.control = "run"
    '''''''''''''''''''''''''''''''''''''''''''''''''''''''''
    ' Anything important needs to run before this sleep.
    '''''''''''''''''''''''''''''''''''''''''''''''''''''''''
    sleep(2000)
    VersionJobs()
    m.top.backgroundUri = ""
    m.top.backgroundColor = m.global.constants.colors.hinted.grey1
    m.activeNode = invalid
    m.followedStreamBar = m.top.findNode("followedStreamsBar")
    m.followedStreamBar.observeField("contentSelected", "onFollowSelected")
    m.menu = m.top.findNode("MenuBar")
    m.menu.menuOptionsText = [
        "Following",
        "Discover",
        "LiveChannels",
        "Categories",
    ]
    m.menu.observeField("buttonSelected", "onMenuSelection")
    m.menu.setFocus(true)
    if get_setting("active_user") = invalid
        set_setting("active_user", "$default$")
    end if
    if get_user_setting("device_code") = invalid
        m.getDeviceCodeTask = CreateObject("roSGNode", "TwitchApiTask")
        m.getDeviceCodeTask.observeField("response", "handleDeviceCode")
        m.getDeviceCodeTask.request = {
            type: "getRendezvouzToken"
        }
        m.getDeviceCodeTask.functionName = m.getDeviceCodeTask.request.type
        m.getDeviceCodeTask.control = "run"
    else
        onMenuSelection()
    end if
    m.footprints = []


end sub

function cleanUserData()
    active_user = get_setting("active_user", "$default$")
    if active_user <> "$default$"
        unset_user_setting("access_token")
        unset_user_setting("device_code")
        ? "default Registry keys: "; getRegistryKeys("$default$")
        NukeRegistry(active_user)
        set_setting("active_user", "$default$")
        ? "active User: "; get_setting("active_user", "$default$")
    else
        for each key in getRegistryKeys("$default$")
            if key <> "temp_device_code"
                if key <> "device_code"
                    unset_user_setting(key)
                end if
            end if
        end for
    end if
end function

function ValidateUserLogin()
    if m.validateOauthToken?.response?.tokenValid <> invalid
        tokenValid = m.validateOauthToken.response.tokenValid
    else
        tokenValid = false
    end if
    if tokenValid
        ? "User Token Seems Valid"
    else
        cleanUserData()
        m.menu.updateUserIcon = true
        ? "pause"
    end if
end function

function focusedMenuItem()
    focusedItem = ""
    if m.menu?.focusedChild?.focusedChild?.id <> invalid
        focusedItem = m.menu.focusedChild.focusedChild.id.toStr()
    end if
    return focusedItem
end function

function VersionJobs()
    if m.global.appinfo.version.major.toInt() = 2 and m.global.appinfo.version.minor.toInt() = 3
        ' Clean Up Job for switching default profile name to "$default$" as "default" is technically a possible twitch user.
        if get_setting("active_user") <> invalid and get_setting("active_user") = "default"
            set_setting("active_user", "$default$")
        end if
    end if
end function

function refreshFollowBar()
    m.followedStreamBar.refreshFollowBar = true
end function

function handleDeviceCode()
    if m.getDeviceCodeTask <> invalid
        response = m.getDeviceCodeTask.response
        set_user_setting("device_code", response.device_code)
        m.followedStreamBar.callFunc("refreshFollowBar")
    end if
    onMenuSelection()
end function

function buildNode(name)
    if name <> invalid
        newNode = createObject("roSGNode", name)
        newNode.id = name
        newNode.translation = "[0, 0]"
        newNode.observeField("backPressed", "onBackPressed")
        newNode.observeField("contentSelected", "onContentSelected")
        if name <> "GamePage" and name <> "ChannelPage" and name <> "VideoPlayer" and name <> "StreamerChannelPage"
            m.top.insertChild(newNode, 1)
        else
            m.top.appendChild(newNode)
        end if
        if name = "LoginPage" or name = "StreamerChannelPage"
            newNode.observeField("finished", "onLoginFinished")
        end if
        return newNode
    end if
end function

sub onLoginFinished()
    m.menu.updateUserIcon = true
    if get_user_setting("device_code") = invalid
        m.getDeviceCodeTask = CreateObject("roSGNode", "TwitchApiTask")
        m.getDeviceCodeTask.observeField("response", "handleDeviceCode")
        m.getDeviceCodeTask.request = {
            type: "getRendezvouzToken"
        }
        m.getDeviceCodeTask.functionName = m.getDeviceCodeTask.request.type
        m.getDeviceCodeTask.control = "run"
    else
        m.followedStreamBar.callFunc("refreshFollowBar")
    end if
    ' if get_setting("active_user", "$default$") <> "$default$"
    '     if m.activeNode.id.toStr() = "LoginPage" or "StreamerChannelPage"
    '         m.top.removeChild(m.activeNode)
    '         m.activeNode = invalid
    '         onMenuSelection()
    '     end if
    ' end if
end sub

function onMenuSelection()
    ' refreshFollowBar()
    ' If user is already logged in, show them their user page
    if focusedMenuItem() = "LoginPage" and get_setting("active_user", "$default$") <> "$default$"
        content = createObject("roSGNode", "TwitchContentNode")
        content.streamerDisplayName = get_user_setting("display_name")
        content.streamerLogin = get_user_setting("login")
        content.streamerId = get_user_setting("id")
        content.streamerProfileImageUrl = get_user_setting("profile_image_url")
        content.contentType = "STREAMER"
        m.activeNode.contentSelected = content
    else
        if m.menu.focusedChild <> invalid
            if m.activeNode <> invalid
                if m.activeNode.id.toStr() <> focusedMenuItem()
                    m.top.removeChild(m.activeNode)
                    m.activeNode = invalid
                end if
            end if
        end if
        if m.activeNode = invalid
            m.activeNode = buildNode(focusedMenuItem())
        end if
        m.activeNode.setfocus(true)
    end if
end function

sub onFollowSelected()
    content = m.followedStreamBar.contentSelected
    if m.activeNode <> invalid
        m.footprints.push(m.activeNode)
        m.activeNode = invalid
    end if
    if m.activeNode = invalid
        m.activeNode = buildNode("ChannelPage")
    end if
    m.activeNode.contentRequested = content
    m.activeNode.setfocus(true)
end sub

sub onContentSelected()
    if m.activeNode.contentSelected.contentType = "STREAMER"
        id = "StreamerChannelPage"
    else if m.activeNode.contentSelected.contentType = "GAME"
        id = "GamePage"
    else if m.activeNode.contentSelected.contentType = "LIVE" or m.activeNode.contentSelected.contentType = "VOD" or m.activeNode.contentSelected.contentType = "USER"
        id = "ChannelPage"
    end if
    if m.activeNode.playContent = true
        id = "VideoPlayer"
    end if
    holdContent = m.activeNode.contentSelected.getFields()
    content = createObject("roSGNode", "TwitchContentNode")
    setTwitchContentFields(content, holdContent)
    if m.activeNode <> invalid
        m.footprints.push(m.activeNode)
        m.activeNode = invalid
    end if
    if m.activeNode = invalid
        m.activeNode = buildNode(id)
    end if
    m.activeNode.contentRequested = content
    m.activeNode.setfocus(true)
end sub

sub onBackPressed()
    ? "backpress detected from: "; m.activeNode.id
    fmi = focusedMenuItem()
    if m.activeNode.backPressed <> invalid and m.activeNode.backPressed
        ? "fmi ping"
        if m.activeNode.id = "StreamerChannelPage"
            if m.footprints[0].id = "LoginPage"
                m.footprints.pop()
            end if
            m.top.removeChild(m.activeNode)
            m.menu.buttonFocus = 0
        end if
        if m.footprints.Count() > 0
            m.top.removeChild(m.activeNode)
            m.activeNode = m.footprints.pop()
            m.activeNode.setFocus(false)
            if focusedMenuItem() = "LoginPage"
                ' if m.menu.buttonFocused = 5
                m.menu.setFocus(true)
            end if
        else
            m.menu.setFocus(true)
        end if
    end if
end sub

function onKeyEvent(key, press) as boolean
    if press
        ? "Hero Scene Key Event: "; key
        if key = "replay"
            ? "----------- Currently Focused Child ----------" + chr(34); m.top.focusedChild
            ? "----------- Last Focused Child ----------" + chr(34); lastFocusedChild(m.top.focusedChild)
            return true
        end if
        if key = "up"
            if m.activeNode.id <> "GamePage" and m.activeNode.id <> "ChannelPage" and m.activeNode.id <> "VideoPlayer"
                m.followedStreamBar.itemHasFocus = false
                m.menu.setFocus(true)
            end if
        end if
        if key = "down"
            m.activeNode.setFocus(true)
        end if
        if key = "left"
            if m.activeNode.id <> "GamePage" and m.activeNode.id <> "ChannelPage" and m.activeNode.id <> "VideoPlayer"
                if get_user_setting("FollowBarOption", "true") = "true"
                    m.activeNode.setFocus(false)
                    m.followedStreamBar.setFocus(true)
                    m.followedStreamBar.itemHasFocus = true
                    return true
                end if
            end if
        end if
        if key = "right"
            if get_user_setting("FollowBarOption", "true") = "true"
                m.followedStreamBar.itemHasFocus = false
                m.activeNode.setFocus(true)
                return true
            end if
        end if
    end if
    ' if key = "up"
    '     m.top.setFocus(true)
    '     return true
    ' end if
    if not press return false
    ? "KEY EVENT: "; key press
end function