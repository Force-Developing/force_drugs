ESX                   		   = nil
local PlayerData      		   = {}
local timer 	      		   = 0
local cancelTimer     		   = false
local pickUpPositions 		   = 0
local CoolDownCoke    		   = false
local CoolDownMeth    		   = false
local CoolDownWeed   		   = false
local DisableControls		   = false

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(player)
	PlayerData = player   
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

Citizen.CreateThread(function()
	while true do
		local sleepThread = 500
		
		local player = GetPlayerPed(-1)
		local pCoords = GetEntityCoords(player)
		local dist1 = #(pCoords - Config.MainPos)

		if dist1 < 50 then
			madebyforce = true
			RequestModel(Config.PedHash) while not HasModelLoaded(Config.PedHash) do Wait(7) end
			if not DoesEntityExist(kallePed) then
				kallePed = CreatePed(4, Config.PedHash, Config.PedPos, Config.PedPosHeading, false, true)
				FreezeEntityPosition(kallePed, true)
				SetBlockingOfNonTemporaryEvents(kallePed, true)
				SetEntityInvincible(kallePed, true)
				ESX.LoadAnimDict("mini@strip_club@idles@bouncer@base")
                TaskPlayAnim(kallePed, 'mini@strip_club@idles@bouncer@base', 'base', 1.0, -1.0, -1, 69, 0, 0, 0, 0)
			end
		else
			madebyforce = false
		end

		if madebyforce then sleepThread = 5 else sleepThread = 500 end

		if dist1 >= 1.5 and dist1 <= 6 then
			if not missionIsStarted then
				DrawText3Ds(Config.PedPosText.x, Config.PedPosText.y, Config.PedPosText.z+1, '[~r~E~w~] Kalle', 0.4)
				DrawMarker(6, Config.MainPos, 0.0, 0.0, 0.0, 270.0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 0, 0, 100, false, true, 2, false, false, false, false)
			end
		end

		if dist1 < 1.5 then
			if not missionIsStarted then
				DrawText3Ds(Config.PedPosText.x, Config.PedPosText.y, Config.PedPosText.z+1, '[~g~E~w~] Kalle', 0.4)
				ESX.ShowHelpNotification('~INPUT_PICKUP~ Snacka med Kalle')
				DrawMarker(6, Config.MainPos, 0.0, 0.0, 0.0, 270.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, true, 2, false, false, false, false)
				if IsControlJustPressed(1, 38) then
					sleepThread = 100
					ChooseDrug()
				end
			end
		end
		Wait(sleepThread)
	end
end)

RegisterNetEvent('force_drugsPickup')
AddEventHandler('force_drugsPickup', function(chosenDrug, Timer)
	while missionIsStarted do
		Wait(7)
		local player = GetPlayerPed(-1)
		local pCoords = GetEntityCoords(player)
		local dist1 = #(pCoords - Config.MainPos)

		if chosenDrug == 'coke' then
			rewardItem = Config.CokeItem
			randomAmount = Config.RandomAmountCoke
        elseif chosenDrug == 'meth' then
			rewardItem = Config.MethItem
			randomAmount = Config.RandomAmountMeth
        elseif chosenDrug == 'weed' then
			rewardItem = Config.WeedItem
			randomAmount = Config.RandomAmountWeed
        end

		if IsEntityDead(player) then
			cancelTimer = true
			timer = 0
			if rewardItem == 'coke' then
			CoolDownCoke = true
			elseif rewardItem == 'meth' then
				CoolDownMeth = true
			elseif rewardItem == 'weed' then
				CoolDownWeed = true
			end
			for _,pos in pairs(Config.PickUpPos) do
				pos.hasPickedUp = false
			end
			pickUpPositions = 0
			RemoveBlip(returnToKalle)
			deliverProducts = false
			missionIsStarted = false
			Wait(100)
			CancelMission()
			ESX.ShowNotification('Du dog och därmed avslutades uppdraget!')
		end

		if not deliverProducts then
				for _,pos in pairs(Config.PickUpPos) do
					if GetDistanceBetweenCoords(pCoords, pos.x, pos.y, pos.z) < 50 and pos.typeOfDrug == chosenDrug then
					RequestModel(pos.objectHash) while not HasModelLoaded(pos.objectHash) do Wait(7) end
					if not pos.hasSpawned then
						pos.objectName = CreateObject(pos.objectHash, pos.x, pos.y, pos.z, true, true, false)
						FreezeEntityPosition(pos.objectName, true)
						pos.hasSpawned = true
					end
				end
			end

			for _,pedPos in pairs(Config.PedPosistions) do
				if GetDistanceBetweenCoords(pCoords, pedPos.x, pedPos.y, pedPos.z) < 50 and pedPos.typeOfDrug == chosenDrug then
					RequestModel(pedPos.pedHash) while not HasModelLoaded(pedPos.pedHash) do Wait(7) end
					if not pedPos.hasSpawned then
						pedPos.pedName = CreatePed(4, pedPos.pedHash, pedPos.x, pedPos.y, pedPos.z, pedPos.h, false, true)
						pedPos.hasSpawned = true
						-- SetPedArmour(pedPos.pedName, 100)
						SetPedCombatAttributes(pedPos.pedName, 46, 1)
						GiveWeaponToPed(pedPos.pedName, pedPos.pedWeapon, 1, false, true)
						SetPedCurrentWeaponVisible(pedPos.pedName, true, false, 0, 0)
						SetPedSeeingRange(pedPos.pedName, 100000000.0)
						SetPedHearingRange(pedPos.pedName, 100000000.0)
						AddRelationshipGroup('hostilePed')
						SetPedRelationshipGroupHash(pedPos.pedName, GetHashKey("hostilePed"))
						SetPedRelationshipGroupHash(player, GetHashKey("Player"))
                        SetRelationshipBetweenGroups(0, GetHashKey("hostilePed"), GetHashKey("hostilePed"))
						SetRelationshipBetweenGroups(5, GetHashKey("hostilePed"), GetHashKey("Player"))
						SetRelationshipBetweenGroups(5, GetHashKey("Player"), GetHashKey("hostilePed"))
					end
				end
			end

			for _,pos in pairs(Config.PickUpPos) do
				if GetDistanceBetweenCoords(pCoords, pos.x, pos.y, pos.z, true) < 1.5 and not pos.hasPickedUp and pos.typeOfDrug == chosenDrug then
					ESX.ShowHelpNotification('~INPUT_PICKUP~ Plocka upp varorna')
					if IsControlJustPressed(1, 38) then
						exports["btrp_progressbar"]:StartDelayedFunction({
							["text"] = "Plockar upp drogerna",
							["delay"] = 10000
						})
						DisableControls = true
						ESX.LoadAnimDict("mini@repair")
						TaskPlayAnim(player, 'mini@repair', 'fixing_a_ped', 1.0, -1.0, 10000, 69, 0, 0, 0, 0)
						FreezeEntityPosition(player, true)
						Wait(10000)
						DisableControls = false
						FreezeEntityPosition(player, false)
						DeleteObject(pos.objectName)
						pickUpPositions = pickUpPositions + 1
						pos.hasPickedUp = true
						ESX.ShowNotification('Du plockade upp ' .. pickUpPositions .. '/' .. Config.pickUpPositions .. ' lådor')
						if pickUpPositions >= Config.pickUpPositions then
							deliverProducts = true
							Wait(1000)
							ESX.ShowNotification(_U('second_done'))
							if not DoesBlipExist(returnToKalle) then
								returnToKalle = AddBlipForCoord(Config.MainPos)
								BlipDetails(returnToKalle, 'Kalle', 46, true)
							end
						end
					end
				else
					if chosenDrug == 'coke' then
					if not DoesBlipExist(PickUpPosBlipRadiusCoke) then
						PickUpPosBlipRadiusCoke = AddBlipForRadius(Config.BlipRadiusPosCoke, 50.0)
						SetBlipAlpha(PickUpPosBlipRadiusCoke, 100)
						SetBlipColour(PickUpPosBlipRadiusCoke, 46)
					end
				end
				if chosenDrug == 'coke' then
					if GetDistanceBetweenCoords(pCoords, Config.BlipRadiusPosCoke) > 50 then
						if not DoesBlipExist(PickUpPosBlipCoke) then
							PickUpPosBlipCoke = AddBlipForCoord(Config.BlipRadiusPosCoke)
							BlipDetails(PickUpPosBlipCoke, 'Lådor', 46, true)
						end
					end
					else
						RemoveBlip(PickUpPosBlipCoke)
					end
					if chosenDrug == 'meth' then
						if not DoesBlipExist(PickUpPosBlipRadiusMeth) then
							PickUpPosBlipRadiusMeth = AddBlipForRadius(Config.BlipRadiusPosMeth, 50.0)
							SetBlipAlpha(PickUpPosBlipRadiusMeth, 100)
							SetBlipColour(PickUpPosBlipRadiusMeth, 46)
						end
					end
					if chosenDrug == 'meth' then
						if GetDistanceBetweenCoords(pCoords, Config.BlipRadiusPosMeth) > 50 then
							if not DoesBlipExist(PickUpPosBlipMeth) then
								PickUpPosBlipMeth = AddBlipForCoord(Config.BlipRadiusPosMeth)
								BlipDetails(PickUpPosBlipMeth, 'Lådor', 46, true)
							end
						end
						else
							RemoveBlip(PickUpPosBlipMeth)
						end
						if chosenDrug == 'weed' then
							if not DoesBlipExist(PickUpPosBlipRadiusWeed) then
								PickUpPosBlipRadiusWeed = AddBlipForRadius(Config.BlipRadiusPosWeed, 50.0)
								SetBlipAlpha(PickUpPosBlipRadiusWeed, 100)
								SetBlipColour(PickUpPosBlipRadiusWeed, 46)
							end
						end
						if chosenDrug == 'weed' then
							if GetDistanceBetweenCoords(pCoords, Config.BlipRadiusPosWeed) > 50 then
								if not DoesBlipExist(PickUpPosBlipWeed) then
									PickUpPosBlipWeed = AddBlipForCoord(Config.BlipRadiusPosWeed)
									BlipDetails(PickUpPosBlipWeed, 'Lådor', 46, true)
								end
							end
							else
								RemoveBlip(PickUpPosBlipWeed)
							end
					DrawMissionText('Ta dig till din GPS destination så fort som möjligt och leta efter lådorna med droger i', 0.96, 0.5)
				end
			end
		end

		if deliverProducts then
			if dist1 < 1.5 then
				ESX.ShowHelpNotification('~INPUT_PICKUP~ Snacka klart med kalle')
				DrawMarker(6, Config.MainPos, 0.0, 0.0, 0.0, 270.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, true, 2, false, false, false, false)
				if IsControlJustPressed(1, 38) then
					ESX.ShowNotification(_U('when_done'))
					TriggerServerEvent('force_drugsGiveReward', rewardItem, randomAmount)
					cancelTimer = true
					timer = 0
					if rewardItem == 'coke' then
					CoolDownCoke = true
					elseif rewardItem == 'meth' then
						CoolDownMeth = true
					elseif rewardItem == 'weed' then
						CoolDownWeed = true
					end
					for _,pos in pairs(Config.PickUpPos) do
						pos.hasPickedUp = false
					end
					pickUpPositions = 0
					RemoveBlip(returnToKalle)
					deliverProducts = false
					missionIsStarted = false
					CancelMission()
				end
			else 
				DrawMissionText('Ta dig tillbaka till Kalle', 0.96, 0.5)
				RemoveBlip(PickUpPosBlipCoke)
				RemoveBlip(PickUpPosBlipWeed)
				RemoveBlip(PickUpPosBlipMeth)
				RemoveBlip(PickUpPosBlipRadiusWeed)
				RemoveBlip(PickUpPosBlipRadiusMeth)
				RemoveBlip(PickUpPosBlipRadiusCoke)
			end
		end
	end
end)

RegisterNetEvent('force_drugsDialog')
AddEventHandler('force_drugsDialog', function()
	local player = GetPlayerPed(-1)

	ESX.ShowNotification(_U('dialog1'))
	Wait(2000)
	ESX.ShowNotification(_U('dialog2'))
	Wait(2000)
	ESX.ShowNotification(_U('dialog3'))
	Wait(2000)
	ESX.ShowNotification(_U('dialog4'))
end)

RegisterNetEvent('force_drugsTimer')
AddEventHandler('force_drugsTimer', function()
    if timer > 0 then
        if Config.DisplayTimer then
            TriggerEvent('force_drugsShowTimer')
            timer = timer - 1
            Wait(1000)
            TriggerEvent('force_drugsTimer')
        end
    else
        if not cancelTimer then
			deliverProducts = false
			missionIsStarted = false
			Wait(1000)
			CancelMission()
			ESX.ShowNotification(_U('to_long'))
			CoolDownCoke = true
			CoolDownMeth = true
			CoolDownWeed = true
        end
    end
end)

RegisterNetEvent('force_drugsShowTimer')
AddEventHandler('force_drugsShowTimer', function()
    while timer > 0 do
        Wait(10)
		DrawMissionText('Tid kvar: ' .. timer .. '\nAntal lådor: ' .. pickUpPositions .. '/' .. Config.pickUpPositions, 0.0, 0.5)
    end
end)

function ChooseDrug()
    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'weamenu',
    {
        title = 'Vill du hjälpa Kalle med Droger?',
        align = 'center',
        elements = {
			{label = 'Kokain', option = 'coke'},
            {label = 'Amfetamin', option = 'meth'},
			{label = 'Marijuana', option = 'weed'},
        }
    },

    function(data, menu)
        -- menu.close()
        local chosen = data.current.option

		if chosen == 'coke' then
			menu.close()
			Wait(100)
			if CoolDownCoke then
				ESX.ShowNotification(_U('wait_8_min'))
				Wait(480000)
				CoolDownCoke = false
			else
			AcceptJob(chosen)
			end
		elseif chosen == 'meth' then
			menu.close()
			Wait(100)
			if CoolDownMeth then
				ESX.ShowNotification(_U('wait_8_min'))
				Wait(480000)
				CoolDownMeth = false
			else
			AcceptJob(chosen)
			end
		elseif chosen == 'weed' then
			menu.close()
			Wait(100)
			if CoolDownWeed then
				ESX.ShowNotification(_U('wait_8_min'))
				Wait(480000)
				CoolDownWeed = false
			else
			AcceptJob(chosen)
			end
        end
    end,
    function(data, menu)
        menu.close()
		ESX.ShowNotification(_U('say_no_to_kalle'))
    end)
end

function AcceptJob(chosenDrug)
    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'weamenu',
    {
        title = 'Vill du hjälpa Kalle?',
        align = 'center',
        elements = {
            {label = 'Ja', option = 'ja'},
            {label = 'Nej', option = 'nej'},
        }
    },

    function(data, menu)
        -- menu.close()
        local chosen = data.current.option

        if chosen == 'ja' then
            missionIsStarted = true
			if chosenDrug == 'coke' then
            timer = Config.missionTimerCoke
			end
			if chosenDrug == 'meth' then
				timer = Config.missionTimerMeth
				end
				if chosenDrug == 'weed' then
					timer = Config.missionTimerWeed
					end
            TriggerEvent('force_drugsTimer')
            TriggerEvent('force_drugsPickup', chosenDrug)
            TriggerEvent('force_drugsDialog')
            menu.close()
        else
            ESX.ShowNotification(_U('say_no_to_kalle'))
            menu.close()
        end
    end,
    function(data, menu)
        menu.close()
		ESX.ShowNotification(_U('say_no_to_kalle'))
    end)
end

Citizen.CreateThread(function()
    while true do
        local sleepThread = 1000

        if DisableControls then
            sleepThread = 5
            DisableAllControlActions(true)
        end
        Wait(sleepThread)
    end
end) 