module Nonlinear
import Luna.PhysData: ε_0, e_ratio
import Luna: Maths

function kerr(E::Array{T, N}, χ3) where T<:Real where N
    return @. ε_0*χ3 * E^3
end

function kerr(E::Array{T, N}, χ3, onlySPM::Val{false}) where T<:Complex where N
    return @. ε_0*χ3/4 * (3*abs2(E) + E^2)*E
end

function kerr(E::Array{T, N}, χ3, onlySPM::Val{true}) where T<:Complex where N
    return @. ε_0*χ3/4 * 3*abs2(E)*E
end

function kerr(E::Array{T, N}, χ3) where T<:Complex where N
    return @. kerr(E, χ3, Val(false))
end

function plasma_phase(t, E::Array{T, N}, ionfrac) where T<:Real where N
    return e_ratio*Maths.cumtrapz(t, Maths.cumtrapz(t, ionfrac.*E))
end

function plasma_loss(t, E::Array{T, N}, ionrate, ionpot) where T<:Real where N
    return Maths.cumtrapz(t, ionpot.*(1 .- ionrate)./E)
end

end