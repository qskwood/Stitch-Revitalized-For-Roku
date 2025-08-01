sub init()
    m.top.observeField("focusedChild", "onGetfocus")
    m.recents = m.top.findnode("recents")
    ' m.recents.buttons = ["Ammo", "paymoneywubby", "three"]
    m.recents.TextColor = m.global.constants.colors.muted.ice
    m.recents.FocusedTextColor = m.global.constants.colors.twitch.purple10
    m.recents.observeField("buttonSelected", "onRecentItemSelected")
    m.kb = m.top.findNode("keyboard")
    m.kb.textEditBox.hintText = tr("Enter Search Query")
    m.kb.textEditBox.voiceEnabled = true
    m.kb.observefield("text", "handleTextInput")
    m.rowlist = m.top.findNode("homeRowList")
    m.rowlist.ObserveField("itemSelected", "handleItemSelected")
    updateRecents()
end sub

function updateRecents(appendItem = invalid)
    oldRecents = ParseJson(get_user_setting("recents", "[]"))
    if oldRecents = invalid
        oldRecents = []
    end if
    newRecents = []
    if appendItem <> invalid
        newRecents.Push(appendItem)
    end if
    for each item in oldRecents
        i = newRecents.count()
        if i < 3
            if item <> appendItem
                newRecents.Push(item)
            end if
        end if
    end for
    set_user_setting("recents", FormatJson(newRecents, 256))
    m.recents.buttons = ParseJson(get_user_setting("recents", "[]"))
    adjustPositionForRecents()
end function

sub onRecentItemSelected()
    selectedText = m.recents.buttons[m.recents.buttonSelected].tostr()
    ? "SelectedText: "; selectedText
    m.kb.setfocus(true)
    m.kb.text = selectedText
end sub

sub adjustPositionForRecents()
    yTranslation = 120
    if m.recents.buttons.count() > 0
        m.recents.buttonHeight = (m.recents.textFont.size * 3)
        ' bound = m.recents.boundingrect()
        ' localbound = m.recents.localboundingrect()
        ' yTranslation = m.recents.localboundingrect().height
        for each button in m.recents.buttons
            yTranslation += (m.recents.textFont.size * 2)
        end for
        ' ? "pause"

        m.kb.translation = [m.kb.translation[0], yTranslation]
    end if
end sub

sub handleTextInput()
    if m.kb.text <> invalid and m.kb.text <> ""
        m.rowlist.visible = false
        m.rowlist.content = invalid
        m.GetContentTask = CreateObject("roSGNode", "TwitchApiTask") ' create task for feed retrieving
        ' observe content so we can know when feed content will be parsed
        m.GetContentTask.observeField("response", "handleRecommendedSections")
        m.GetContentTask.request = {
            query: m.kb.text.toStr()
        }
        m.getcontentTask.functionName = "getSearchQuery"
        m.getcontentTask.control = "run"
    end if
end sub

sub handleRecommendedSections()
    if m.GetContentTask?.response?.data <> invalid
        ' ?"data: "; m.GetContentTask.response.data
        if m.GetContentTask?.response?.data?.searchFor <> invalid
            ' ? "searchFor: "m.GetContentTask.response.data.searchFor
            contentCollection = buildContentNodeFromShelves(m.GetContentTask.response.data.searchFor)
        end if
    end if
end sub

function buildContentNodeFromShelves(shelves)
    LiveChannels = []
    Users = []
    Games = []
    Vods = []
    for each item in shelves.channels.items
        rowItem = {}
        if item.stream <> invalid
            rowItem.contentType = "LIVE"
        else
            rowItem.contentType = "USER"
        end if
        if rowItem.contentType = "LIVE"
            rowItem.contentId = item.stream.Id
            rowItem.createdAt = item.stream.createdAt
            rowItem.previewImageURL = Substitute("https://static-cdn.jtvnw.net/previews-ttv/live_user_{0}-{1}x{2}.jpg", item.stream.broadcaster.login, "1280", "720")
            rowItem.contentTitle = item.stream.broadcaster.broadcastSettings.title
            rowItem.viewersCount = item.stream.viewersCount
            rowItem.streamerDisplayName = item.stream.broadcaster.displayName
            rowItem.streamerLogin = item.stream.broadcaster.login
            rowItem.streamerId = item.stream.broadcaster.id
            rowItem.streamerProfileImageUrl = item.stream.broadcaster.profileImageURL
            if item.stream.game <> invalid
                rowItem.gameDisplayName = item.stream.game.displayName
                rowItem.gameBoxArtUrl = Left(item.stream.game.boxArtUrl, Len(item.stream.game.boxArtUrl) - 20) + "188x250.jpg"
                rowItem.gameId = item.stream.game.Id
                rowItem.gameName = item.stream.game.name
            end if
            LiveChannels.push(rowItem)
        end if
        if rowItem.contentType = "USER"
            rowItem.contentId = item.Id
            rowItem.previewImageURL = Substitute("https://static-cdn.jtvnw.net/previews-ttv/live_user_{0}-{1}x{2}.jpg", item.login, "1280", "720")
            rowItem.contentTitle = item.displayName
            rowItem.followerCount = item.followers.totalCount
            rowItem.streamerDisplayName = item.displayName
            rowItem.streamerLogin = item.login
            rowItem.streamerId = item.id
            rowItem.streamerProfileImageUrl = item.profileImageURL
            Users.push(rowItem)
        end if
    end for
    for each game in shelves.games.items
        rowItem = {}
        rowItem.contentId = game.Id
        rowItem.contentType = "GAME"
        rowItem.viewersCount = game.viewersCount
        rowItem.contentTitle = game.displayName
        rowItem.gameDisplayName = game.displayName
        rowItem.gameBoxArtUrl = Left(game.boxArtUrl, Len(game.boxArtUrl) - 20) + "188x250.jpg"
        rowItem.gameId = game.Id
        rowItem.gameName = game.name
        Games.push(rowItem)
    end for
    for each VOD in shelves.videos.items
        rowItem = {}
        rowItem.contentType = "VOD"
        rowItem.contentId = VOD.Id
        if VOD.previewThumbnailURL <> invalid
            rowItem.previewImageURL = Left(VOD.previewThumbnailURL, len(VOD.previewThumbnailURL) - 20) + "320x180." + Right(VOD.previewThumbnailURL, 3)
        else if VOD.thumbnailURL <> invalid
            rowItem.previewImageURL = VOD.thumbnailURL
        end if
        rowItem.contentTitle = VOD.title
        rowItem.viewersCount = VOD.viewCount
        rowItem.streamerDisplayName = VOD.owner.displayName
        rowItem.streamerLogin = VOD.owner.login
        rowItem.streamerId = VOD.owner.id
        if VOD.game <> invalid
            rowItem.gameDisplayName = VOD.game.displayName
            rowItem.gameBoxArtUrl = Left(VOD.game.boxArtUrl, Len(VOD.game.boxArtUrl) - 20) + "188x250.jpg"
            rowItem.gameId = VOD.game.Id
            rowItem.gameName = VOD.game.name
        end if
        Vods.push(rowItem)
    end for
    AllContent = createObject("roSGNode", "ContentNode")
    firstRow = createObject("roSGNode", "ContentNode")
    firstRow.title = tr("Live Channels")
    for each stream in LiveChannels
        rowItem = createObject("RoSGNode", "TwitchContentNode")
        setTwitchContentFields(rowItem, stream)
        firstRow.appendChild(rowItem)
    end for
    secondRow = createObject("roSGNode", "ContentNode")
    secondRow.title = tr("Channels")
    for each User in Users
        rowItem = createObject("RoSGNode", "TwitchContentNode")
        setTwitchContentFields(rowItem, User)
        secondRow.appendChild(rowItem)
    end for
    thirdRow = createObject("roSGNode", "ContentNode")
    thirdRow.title = tr("Categories")
    for each Game in Games
        rowItem = createObject("RoSGNode", "TwitchContentNode")
        setTwitchContentFields(rowItem, Game)
        thirdRow.appendChild(rowItem)
    end for
    fourthRow = createObject("roSGNode", "ContentNode")
    fourthRow.title = tr("VODs")
    for each Vod in Vods
        rowItem = createObject("RoSGNode", "TwitchContentNode")
        setTwitchContentFields(rowItem, Vod)
        fourthRow.appendChild(rowItem)
    end for
    ' set content and heights
    rowItemSize = []
    rowHeights = []
    if firstRow.getChildCount() > 0
        rowItemSize.push([320, 180])
        rowheights.push(275)
        AllContent.appendChild(firstRow)
    end if
    if secondRow.getchildCount() > 0
        rowItemSize.push([150, 150])
        rowHeights.push(200)
        AllContent.appendChild(secondRow)
    end if
    if thirdRow.getchildCount() > 0
        rowItemSize.push([188, 250])
        rowHeights.push(325)
        AllContent.appendChild(thirdRow)
    end if
    if fourthRow.getchildCount() > 0
        rowItemSize.push([320, 180])
        rowheights.push(275)
        AllContent.appendchild(fourthRow)
    end if
    m.rowlist.visible = false
    m.rowlist.content = AllContent
    m.rowlist.rowHeights = rowHeights
    m.rowlist.rowItemSize = rowItemSize
    m.rowlist.visible = true
end function


sub handleItemSelected()
    if m.kb.text <> ""
        updateRecents(m.kb.text)
    end if
    selectedRow = m.rowlist.content.getchild(m.rowlist.rowItemSelected[0])
    selectedItem = selectedRow.getChild(m.rowlist.rowItemSelected[1])
    m.top.contentSelected = selectedItem
end sub


sub onGetFocus()
    if m.rowlist.focusedchild <> invalid
        if m.rowlist.focusedChild.id = "homeRowList"
            m.rowlist.focusedChild.setFocus(true)
        end if
    else if m.top.focusedChild <> invalid
        if m.top.focusedChild.id = "Search"
            m.kb.setFocus(true)
        else if m.top.focusedChild.id = "homeRowList"
            m.rowlist.setfocus(true)
        end if
    else
        m.top.setfocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press
        ? "Search Key Press: "; key
        if key = "right"
            if m.top.focusedChild.id = "keyboard" or m.top.focusedChild.id = "recents"
                m.kb.setfocus(false)
                m.rowlist.setfocus(true)
                return true
            end if
        end if
        if key = "left"
            if m.top.focusedChild.id = "homeRowList"
                m.rowlist.setfocus(false)
                m.kb.setfocus(true)
                return true
            end if
        end if
        if key = "up" or key = "back"
            if m.top?.focusedChild?.id <> invalid and m.top.focusedChild.id = "keyboard"
                if m.recents.buttons.count() > 0
                    m.recents.setfocus(true)
                    ' m.kb.setfocus(false)
                    return true
                end if
            end if
            m.rowlist.setfocus(false)
            m.kb.setfocus(false)
            m.top.backPressed = true
            return true
        end if
        if key = "down"
            if m.top?.focusedChild?.id <> invalid and m.top.focusedChild.id = "recents"
                m.kb.setfocus(true)
                return true
            end if
        end if
    end if
end function