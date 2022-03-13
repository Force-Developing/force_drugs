function DrawMissionText(text, height, length)
    SetTextScale(0.5, 0.5)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextEntry("STRING")
    SetTextCentre(1)
    SetTextOutline()
    AddTextComponentString(text)
    DrawText(length, height)
end

function BlipDetails(blipName, blipText, color, route)
    BeginTextCommandSetBlipName("STRING")
    SetBlipColour(blipName, color)
    AddTextComponentString(blipText)
    SetBlipRoute(blipName, route)
    EndTextCommandSetBlipName(blipName)
end

function DrawText3Ds(x,y,z, text, scale)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())

    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
end

function CancelMission()
    RemoveBlip(PickUpPosBlipCoke)
    RemoveBlip(PickUpPosBlipWeed)
    RemoveBlip(PickUpPosBlipMeth)
    RemoveBlip(PickUpPosBlipRadius)
    RemoveBlip(returnToKalle)
    RemoveBlip(PickUpPosBlipRadiusWeed)
    RemoveBlip(PickUpPosBlipRadiusMeth)
    RemoveBlip(PickUpPosBlipRadiusCoke)
end