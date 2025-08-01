function updateViewersDisplay()
    suffix = ""
    if m.top.contentType = "LIVE"
        suffix = tr("Viewers")
    end if
    if m.top.contentType = "VOD"
        suffix = tr("Views")
    end if
    if m.top.contentType = "CLIP"
        suffix = tr("Views")
    end if
    if m.top.contentType = "GAME"
        suffix = tr("Viewers")
    end if
    m.top.viewersDisplay = Substitute("{0} {1}", numberToText(m.top.viewersCount), suffix)
end function

function updateFollowerDisplay()
    suffix = tr("Followers")
    m.top.followerDisplay = Substitute("{0} {1}", numberToText(m.top.followerCount), suffix)
end function

sub updateRelativePublishDate()
    m.top.relativePublishDate = getRelativeTimePublished(m.top.datePublished)
end sub

sub updateCreatedAtSeconds()
    ' secondsSincePublished = createObject("roDateTime")
    ' m.top.streamerDisplayName = secondsSincePublished.FromISO8601String(m.top.createdAt)
end sub

sub updateType()
    if m.top.contentType = "LIVE"
        m.top.live = true
        m.top.streamFormat = "lhls"
    end if
    if m.top.contentType = "VOD"
        m.top.live = false
        m.top.streamFormat = "hls"
    end if
    if m.top.contentType = "CLIP"
        m.top.live = false
        m.top.streamFormat = "mp4"
    end if
    if m.top.contentType = "GAME"
    end if
end sub


sub updateTitle()
    m.top.title = m.top.contentTitle
end sub