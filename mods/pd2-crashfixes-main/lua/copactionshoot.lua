local __update = CopActionShoot.update
local __get_unit_shoot_pos = CopActionShoot._get_unit_shoot_pos

--[string "lib/units/enemies/cop/actions/upper_body/copa..."]:402: attempt to index field '_weapon_base' (a nil value)
function CopActionShoot:update(...)
    if self._weapon_base then
        __update(self, ...)
    end
end

--[string "lib/units/enemies/cop/actions/upper_body/copa..."]:674: attempt to index local 'w_tweak' (a number value)
function CopActionShoot:_get_unit_shoot_pos(t, pos, dis, w_tweak, ...)
    if type(w_tweak) == "table" then
        return __get_unit_shoot_pos(self, t, pos, dis, w_tweak, ...)
    end
end
