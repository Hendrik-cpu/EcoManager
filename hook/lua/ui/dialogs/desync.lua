local dialog

function UpdateDialog(beatNumber, strings)
    if not dialog then
        dialog = Group(GetFrame(0), "updateDialogGroup")

        dialog.Width:Set(200)
        dialog.Height:Set(250)
        dialog.Depth:Set(GetFrame(0):GetTopmostDepth() + 10)
        LayoutHelpers.AtCenterIn(dialog, GetFrame(0))
        local border, bg = UIUtil.CreateBorder(dialog, true)

        local title = UIUtil.CreateText(bg, "<LOC desync_0000>Desync Detected", 14, UIUtil.titleFont)
        LayoutHelpers.AtTopIn(title, dialog, 5)
        LayoutHelpers.AtHorizontalCenterIn(title, dialog)

        dialog.textControls = {}
        local prev = false
        for i = 1,9 do
            dialog.textControls[i] = UIUtil.CreateText(bg, "", 12, UIUtil.bodyFont)
            if prev then
                LayoutHelpers.Below(dialog.textControls[i], prev, 5)
            else
                LayoutHelpers.AtLeftIn(dialog.textControls[i], bg, 5)
                dialog.textControls[i].Top:Set(function() return title.Bottom() + 5 end)
            end
            prev = dialog.textControls[i]
        end

        local okBtn = UIUtil.CreateButtonStd(bg, '/widgets/small', "Hide", 10)
        okBtn.Top:Set(dialog.textControls[9].Bottom)
        LayoutHelpers.AtHorizontalCenterIn(okBtn, bg)

        okBtn.OnClick = function(self, modifiers)
            dialog:Hide()
        end
    end

    for i = 1,8 do
        if strings[i] then
            dialog.textControls[i]:SetText(strings[i])
        end
    end
    dialog.textControls[9]:SetText(LOC("<LOC desync_0001>Beat# ") .. tostring(beatNumber))
end
