local players = game:GetService("Players");
local workspace = game:GetService("Workspace");
local runService = game:GetService("RunService");
local inputService = game:GetService("UserInputService");
local networkClient = game:GetService("NetworkClient");
local virtualUser = game:GetService("VirtualUser");
local lighting = game:GetService("Lighting");
local teleportService = game:GetService("TeleportService");

local camera = workspace.CurrentCamera;
local localplayer = players.LocalPlayer;
local mouse = localplayer:GetMouse();
local curveStatus = {player = nil, i = 0};
local fovCircle = Drawing.new("Circle");
local ambient = lighting.Ambient;
local keybinds = {};
local xray = {};
local fonts = {};
for font, index in next, Drawing.Fonts do
    fonts[index] = font;
end

local uiLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/zzvsvv/zv-softwares/main/script/libs/Orion.lua"))();
local espLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/zzvsvv/zv-softwares/main/libs/esp.lua"))();

local function connect(signal, callback)
    local connection = signal:Connect(callback);
    table.insert(uiLibrary.Connections, connection);
    return connection;
end

local function getFlag(name)
    return uiLibrary.Flags[name].Value;
end

local function isR15(character)
    return character:FindFirstChild("UpperTorso") ~= nil;
end

local function getHitpart(character)
    local hitpart = getFlag("combot_aimbot_hitpart");
    if hitpart == "Torso" and isR15(character) then
        hitpart = "UpperTorso";
    end
    return character:FindFirstChild(hitpart);
end

local function isCharacterPart(part)
    for _, player in next, players:GetPlayers() do
        if player.Character and part:IsDescendantOf(player.Character) then
            return true;
        end
    end
    return false;
end

local function wtvp(worldPosition)
    local screenPosition, inBounds = camera:WorldToViewportPoint(worldPosition);
    return Vector2.new(screenPosition.X, screenPosition.Y), inBounds, screenPosition.Z;
end

local function getClosest(fov, teamcheck)
    local returns = {};
    local lastMagnitude = fov or math.huge;
    for _, player in next, players:GetPlayers() do
        if (teamcheck and player.Team == localplayer.Team) or player == localplayer then
            continue;
        end

        local character = player.Character;
        local part = character and getHitpart(character);
        if character and part then
            local partPosition = part.Position;
            if getFlag("combat_aimbot_prediction") then
                partPosition += part.Velocity * getFlag("combat_aimbot_predictioninterval");
            end

            local screenPosition, inBounds = wtvp(partPosition);
            local mousePosition = inputService:GetMouseLocation();
            local magnitude = (screenPosition - mousePosition).Magnitude;
            if magnitude < lastMagnitude and inBounds then
                lastMagnitude = magnitude;
                returns = table.pack(player, screenPosition, part);
            end
        end
    end
    return table.unpack(returns);
end

local function isVisible(part)
    return #camera:GetPartsObscuringTarget({ part.Position }, { camera, part.Parent, localplayer.Character }) == 0;
end

local function bezierCurve(bezierType, t, p0, p1)
    if bezierType == "Linear" then
        return (1-t)*p0 + t*p1;
    else
        return (1 - t)^2 * p0 + 2 * (1 - t) * t * (p0 + (p1 - p0) * Vector2.new(0.5, 0)) + t^2 * p1;
    end
end

-- ui
local window = uiLibrary:MakeWindow({ Name = "zh software", HidePremium = false, SaveConfig = true, ConfigFolder = "zh softwares" });
do
    local combat = window:MakeTab({ Name = "Combat" });
    do
        local aimbot = combat:AddSection({ Name = "Aimbot" });
        do
            aimbot:AddToggle({ Name = "Enabled", Default = false, Save = true, Flag = "combat_aimbot_enabled" });
            aimbot:AddBind({ Name = "Toggle Key", Default = Enum.UserInputType.MouseButton2, Hold = true, Save = true, Flag = "combat_aimbot_key", Callback = function(state)
                keybinds["combat_aimbot_key"] = state;
            end });
            aimbot:AddSlider({ Name = "Step Size", Default = 50, Min = 1, Max = 50, Save = true, ValueName = "percent per centisecond", Flag = "combat_aimbot_stepsize" });
            aimbot:AddDropdown({ Name = "Type", Default = "Linear", Options = {"Linear", "Curve"}, Save = true, Flag = "combat_aimbot_type" });
            aimbot:AddDropdown({ Name = "Hitpart", Default = "Head", Options = {"Head", "Torso"}, Save = true, Flag = "combot_aimbot_hitpart" });
            aimbot:AddToggle({ Name = "Prediction", Default = false, Save = true, Flag = "combat_aimbot_prediction" });
            aimbot:AddSlider({ Name = "Prediction Interval", Default = 0.01, Min = 0.001, Max = 0.1, Increment = 0.001, ValueName = "seconds", Save = true, Flag = "combat_aimbot_predictioninterval" });
            aimbot:AddToggle({ Name = "Team Check", Default = true, Save = true, Flag = "combat_aimbot_teamcheck" });
            aimbot:AddToggle({ Name = "Visible Check", Default = false, Save = true, Flag = "combat_aimbot_visiblecheck" });
        end

        local fov = combat:AddSection({ Name = "FOV" });
        do
            fov:AddToggle({ Name = "Enabled", Default = false, Save = true, Flag = "combat_fov_enabled" });
            fov:AddToggle({ Name = "Visible", Default = true, Save = true, Flag = "combat_fov_visible" });
            fov:AddColorpicker({ Name = "Color", Default = Color3.new(1,1,1), Save = true, Flag = "combat_fov_color" });
            fov:AddSlider({ Name = "Size", Default = 100, Min = 5, Max = 1000, ValueName = "px", Save = true, Flag = "combat_fov_size" });
        end
    end

    local visuals = window:MakeTab({ Name = "Visuals" });
    do
        local esp = visuals:AddSection({ Name = "ESP" });
        do
            esp:AddToggle({ Name = "Enabled", Default = false, Save = true, Flag = "visuals_esp_enabled", Callback = function(value)
                espLibrary.options.enabled = value;
            end });

            esp:AddToggle({ Name = "Boxes", Default = false, Save = true, Flag = "visuals_esp_boxes", Callback = function(value)
                espLibrary.options.boxes = value;
            end });

            esp:AddToggle({ Name = "Filled Boxes", Default = false, Save = true, Flag = "visuals_esp_filledboxes", Callback = function(value)
                espLibrary.options.boxFill = value;
            end });

            esp:AddToggle({ Name = "Healthbar", Default = false, Save = true, Flag = "visuals_esp_healthbar", Callback = function(value)
                espLibrary.options.healthBars = value;
            end });

            esp:AddToggle({ Name = "Health Text", Default = false, Save = true, Flag = "visuals_esp_healthtext", Callback = function(value)
                espLibrary.options.healthText = value;
            end });

            esp:AddToggle({ Name = "Names", Default = false, Save = true, Flag = "visuals_esp_names", Callback = function(value)
                espLibrary.options.names = value;
            end });

            esp:AddToggle({ Name = "Distance", Default = false, Save = true, Flag = "visuals_esp_distance", Callback = function(value)
                espLibrary.options.distance = value;
            end });

            esp:AddToggle({ Name = "Chams", Default = false, Save = true, Flag = "visuals_esp_chams", Callback = function(value)
                espLibrary.options.chams = value;
            end });

            esp:AddToggle({ Name = "Tracers", Default = false, Save = true, Flag = "visuals_esp_tracers", Callback = function(value)
                espLibrary.options.tracers = value;
            end });

            esp:AddToggle({ Name = "Out-of-view arrows", Default = false, Save = true, Flag = "visuals_esp_oofarrows", Callback = function(value)
                espLibrary.options.outOfViewArrows = value;
                espLibrary.options.outOfViewArrowsOutline = value;
            end });
        end

        local espSettings = visuals:AddSection({ Name = "ESP Settings" });
        do
            espSettings:AddColorpicker({ Name = "Box Color", Default = Color3.new(1,1,1), Save = true, Flag = "visuals_espsettings_boxcolor", Callback = function(value)
                espLibrary.options.boxesColor = value;
            end });

            espSettings:AddColorpicker({ Name = "Filled Box Color", Default = Color3.new(1,1,1), Save = true, Flag = "visuals_espsettings_filledboxcolor", Callback = function(value)
                espLibrary.options.boxFillColor = value;
            end });

            espSettings:AddColorpicker({ Name = "Healthbar Color", Default = Color3.new(0,1,0), Save = true, Flag = "visuals_espsettings_healthbarcolor", Callback = function(value)
                espLibrary.options.healthBarsColor = value;
            end });

            espSettings:AddColorpicker({ Name = "Healthtext Color", Default = Color3.new(0,1,0), Save = true, Flag = "visuals_espsettings_healthtextcolor", Callback = function(value)
                espLibrary.options.healthTextColor = value;
            end });

            espSettings:AddColorpicker({ Name = "Names Color", Default = Color3.new(1,1,1), Save = true, Flag = "visuals_espsettings_namescolor", Callback = function(value)
                espLibrary.options.nameColor = value;
            end });

            espSettings:AddColorpicker({ Name = "Distance Color", Default = Color3.new(1,1,1), Save = true, Flag = "visuals_espsettings_distancecolor", Callback = function(value)
                espLibrary.options.distanceColor = value;
            end });

            espSettings:AddColorpicker({ Name = "Chams Color", Default = Color3.new(1,0,0), Save = true, Flag = "visuals_espsettings_chamscolor", Callback = function(value)
                espLibrary.options.chamsFillColor = value;
            end });

            espSettings:AddColorpicker({ Name = "Tracer Color", Default = Color3.new(1,1,1), Save = true, Flag = "visuals_espsettings_tracercolor", Callback = function(value)
                espLibrary.options.tracerColor = value;
            end });
            
            espSettings:AddColorpicker({ Name = "OOF Arrows Color", Default = Color3.new(1,1,1), Save = true, Flag = "visuals_espsettings_oofarrowscolor", Callback = function(value)
                espLibrary.options.outOfViewArrowsColor = value;
                espLibrary.options.outOfViewArrowsOutlineColor = value;
            end });

            espSettings:AddToggle({ Name = "Use Teamcolor", Default = false, Save = true, Flag = "visuals_espsettings_useteamcolor", Callback = function(value)
                espLibrary.options.teamColor = value;
            end });

            espSettings:AddToggle({ Name = "Team Check", Default = true, Save = true, Flag = "visuals_espsettings_teamcheck", Callback = function(value)
                espLibrary.options.teamCheck = value;
            end });

            espSettings:AddToggle({ Name = "Visible Check", Default = false, Save = true, Flag = "visuals_espsettings_visiblecheck", Callback = function(value)
                espLibrary.options.visibleOnly = value;
            end });

            espSettings:AddToggle({ Name = "Limit Distance", Default = false, Save = true, Flag = "visuals_espsettings_limitdistance", Callback = function(value)
                espLibrary.options.limitDistance = value;
            end });

            espSettings:AddSlider({ Name = "Max Distance", Default = 1000, Min = 50, Max = 2000, ValueName = "studs", Save = true, Flag = "visuals_espsettings_maxdistance", Callback = function(value)
                espLibrary.options.maxDistance = value;
            end });

            espSettings:AddSlider({ Name = "Font Size", Default = 13, Min = 5, Max = 25, ValueName = "px", Save = true, Flag = "visuals_espsettings_fontsize", Callback = function(value)
                espLibrary.options.fontSize = value;
            end });

            espSettings:AddDropdown({ Name = "Font", Default = fonts[2], Options = fonts, Save = true, Flag = "visuals_espsettings_font", Callback = function(value)
                espLibrary.options.font = Drawing.Fonts[value];
            end });

            espSettings:AddDropdown({ Name = "Tracer Origin", Default = "Bottom", Options = {"Bottom", "Top", "Mouse"}, Save = true, Flag = "visuals_espsettings_tracerorigin", Callback = function(value)
                espLibrary.options.tracerOrigin = value;
            end });
        end
    end

    local movement = window:MakeTab({ Name = "Movement" });
    do
        local character = movement:AddSection({ Name = "Character" });
        do
            character:AddToggle({ Name = "Walkspeed", Default = false, Save = true, Flag = "movement_character_walkspeed" });
            character:AddSlider({ Name = "Value", Min = 1, Max = 200, Default = 16, ValueName = "studs/s", Save = true, Flag = "movement_character_walkspeed_value" });

            character:AddToggle({ Name = "Jumpheight", Default = false, Save = true, Flag = "movement_character_jumpheight" });
            character:AddSlider({ Name = "Value", Min = 0, Max = 200, Default = 7.2, ValueName = "studs", Save = true, Flag = "movement_character_jumpheight_value" });

            character:AddToggle({ Name = "Hipheight", Default = false, Save = true, Flag = "movement_character_hipheight" });
            character:AddSlider({ Name = "Value", Min = -2, Max = 10, Default = 0, ValueName = "studs", Increment = 0.5, Save = true, Flag = "movement_character_hipheight_value" });

            character:AddToggle({ Name = "Fly", Default = false, Save = true, Flag = "movement_character_fly" });
            character:AddSlider({ Name = "Speed", Min = 10, Max = 200, Default = 100, ValueName = "studs/s", Save = true, Flag = "movement_character_fly_value" });

            character:AddToggle({ Name = "Infinite Jump", Default = false, Save = true, Flag = "movement_character_infinitejump" });
        end

        local teleporting = movement:AddSection({ Name = "Teleporting" });
        do
            local playerName = "";
            teleporting:AddTextbox({ Name = "Player", TextDisappear = true, Save = false, Callback = function(value)
                playerName = string.lower(value);
            end });

            teleporting:AddButton({ Name = "Teleport", Callback = function()
                local character = localplayer.Character;
                if character then
                    local player;
                    for _, plr in next, players:GetPlayers() do
                        if string.find(string.lower(plr.Name), playerName) or string.find(string.lower(plr.DisplayName), playerName) then
                            player = plr;
                        end
                    end

                    if player and player.Character then
                        character:PivotTo(player.Character:GetPivot());
                    end
                end
            end });

            teleporting:AddToggle({ Name = "Click TP", Default = false, Save = true, Flag = "movement_teleporting_clicktp"});
        end
    end

    local other = window:MakeTab({ Name = "Other" });
    do
        local exploits = other:AddSection({ Name = "Exploits" });
        do
            exploits:AddToggle({ Name = "No-Clip", Default = false, Save = true, Flag = "other_exploits_noclip" });

            exploits:AddToggle({ Name = "Fake Lag", Default = false, Save = true, Flag = "other_exploits_fakelag", Callback = function(value)
                networkClient:SetOutgoingKBPSLimit(value and 1 or 0);
            end });

            exploits:AddToggle({ Name = "Anti AFK", Default = true, Save = true, Flag = "other_exploits_antiafk" });
        end

        local lighting = other:AddSection({ Name = "Lighting" });
        do
            lighting:AddToggle({ Name = "Ambient", Default = false, Save = true, Flag = "other_lighting_ambient" });
            lighting:AddColorpicker({ Name = "Ambient Color", Default = Color3.new(1,1,1), Save = true, Flag = "other_lighting_ambientcolor" });

            lighting:AddToggle({ Name = "Custom Time", Default = false, Save = true, Flag = "other_lighting_customtime" });
            lighting:AddSlider({ Name = "Time Value", Default = 12, Min = 0, Max = 24, Increment = 0.5, Save = true, Flag = "other_lighting_timevalue" });
        end

        local _game = other:AddSection({ Name = "Game" });
        do
            _game:AddToggle({ Name = "X-Ray", Default = false, Save = true, Flag = "other_game_xray", Callback = function(value)
                if value then
                    for _, part in next, workspace:GetDescendants() do
                        if part:IsA("BasePart") and part.Transparency ~= 1 and not part:IsDescendantOf(camera) and not isCharacterPart(part) then
                            if not xray[part] or xray[part] ~= part.Transparency then
                                xray[part] = part.Transparency;
                            end
                            part.Transparency = 0.75;
                        end
                    end
                else
                    for _, part in next, workspace:GetDescendants() do
                        if xray[part] then
                            part.Transparency = xray[part];
                        end
                    end
                end
            end });

            _game:AddButton({ Name = "Rejoin Game", Callback = function()
                teleportService:Teleport(game.PlaceId);
            end });
        end
    end
end

-- connections
connect(localplayer.Idled, function()
    if getFlag("other_exploits_antiafk") then
        virtualUser:ClickButton1(Vector2.zero, camera);
    end
end);

connect(runService.Stepped, function()
    if getFlag("other_exploits_noclip") then
        local character = localplayer.Character;
        if character then
            for _, part in next, character:GetDescendants() do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false;
                end
            end
        end
    end
end);

connect(runService.Heartbeat, function()
    if getFlag("other_lighting_ambient") then
        lighting.Ambient = getFlag("other_lighting_ambientcolor");
    else
        lighting.Ambient = ambient;
    end
    if getFlag("other_lighting_customtime") then
        lighting.ClockTime = getFlag("other_lighting_timevalue");
    end
end);

connect(runService.Heartbeat, function()
    local character = localplayer.Character;
    local humanoid = character and character:FindFirstChildOfClass("Humanoid");
    if humanoid then
        if getFlag("movement_character_walkspeed") then
            humanoid.WalkSpeed = getFlag("movement_character_walkspeed_value");
        end
        if getFlag("movement_character_jumpheight") then
            humanoid.UseJumpPower = false;
            humanoid.JumpHeight = getFlag("movement_character_jumpheight_value");
        end
        if getFlag("movement_character_hipheight") then
            humanoid.HipHeight = getFlag("movement_character_hipheight_value");
        end
        if getFlag("movement_character_fly") then
            local rootPart = humanoid.RootPart;
            local velocity = Vector3.zero;
            if inputService:IsKeyDown(Enum.KeyCode.W) then
                velocity += camera.CFrame.LookVector;
            end
            if inputService:IsKeyDown(Enum.KeyCode.S) then
                velocity += -camera.CFrame.LookVector;
            end
            if inputService:IsKeyDown(Enum.KeyCode.D) then
                velocity += camera.CFrame.RightVector;
            end
            if inputService:IsKeyDown(Enum.KeyCode.A) then
                velocity += -camera.CFrame.RightVector;
            end
            if inputService:IsKeyDown(Enum.KeyCode.Space) then
                velocity += rootPart.CFrame.UpVector;
            end
            if inputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                velocity += -rootPart.CFrame.UpVector;
            end
            rootPart.Velocity = velocity * getFlag("movement_character_fly_value");
        end
    end
end);

connect(inputService.InputBegan, function(input, processed)
    if input.UserInputType.Name == "MouseButton1" and not processed and getFlag("movement_teleporting_clicktp") then
        local character = localplayer.Character;
        local camPos = camera.CFrame.Position;

        local ray = Ray.new(camPos, mouse.Hit.Position - camPos);
        local _, hit, normal = workspace:FindPartOnRayWithIgnoreList(ray, { camera });
        if hit and normal then
            character:PivotTo(CFrame.new(hit + normal));
        end
    end
    if input.KeyCode.Name == "Space" and not processed and getFlag("movement_character_infinitejump") then
        local character = localplayer.Character;
        local humanoid = character and character:FindFirstChildOfClass("Humanoid");
        if humanoid then
            humanoid:ChangeState("Jumping");
        end 
    end
end);

connect(runService.RenderStepped, function()
    fovCircle.Visible = getFlag("combat_fov_enabled") and getFlag("combat_fov_visible");
    if fovCircle.Visible then
        fovCircle.Position = inputService:GetMouseLocation();
        fovCircle.Color = getFlag("combat_fov_color");
        fovCircle.Radius = getFlag("combat_fov_size");
        fovCircle.NumSides = 1000;
        fovCircle.Thickness = 1;
    end
end);

connect(runService.Heartbeat, function(deltaTime)
    if getFlag("combat_aimbot_enabled") and keybinds["combat_aimbot_key"] then
        local fov = getFlag("combat_fov_enabled") and getFlag("combat_fov_size");
        local player, screenPosition, part = getClosest(fov, getFlag("combat_aimbot_teamcheck"));
        if player and screenPosition and part then
            if getFlag("combat_aimbot_visiblecheck") and not isVisible(part) then
                return;
            end

            if curveStatus.player ~= player then
                curveStatus = {player = player, i = 0};
            end

            local mousePosition = inputService:GetMouseLocation();
            local delta = bezierCurve(getFlag("combat_aimbot_type"), curveStatus.i, mousePosition, screenPosition) - mousePosition;
            mousemoverel(delta.X, delta.Y);

            local stepSize = getFlag("combat_aimbot_stepsize");
            local increment = (stepSize / 100) * (deltaTime * 100);
            curveStatus.i = math.clamp(curveStatus.i + increment, 0, 1);
        else
            curveStatus = {player = nil, i = 0};
        end
    else
        curveStatus = {player = nil, i = 0};
    end
end);

espLibrary:Load();
uiLibrary:Init();
