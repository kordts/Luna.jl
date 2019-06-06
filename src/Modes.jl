"Functions which define the modal decomposition. This includes

    1. Mode normalisation
    2. Modal decomposition of Pₙₗ

Wishlist of types of decomposition we want to use:

    1. Mode-averaged waveguide
    2. Multi-mode waveguide (with or without polarisation)
        a. Azimuthal symmetry (radial integral only)
        b. Full 2-D integral
    3. Free space
        a. Azimuthal symmetry (Hankel transform)
        b. Full 2-D (Fourier transform)"
module Modes
import FFTW
import LinearAlgebra: mul!
import Luna:PhysData

"Transform A(ω) to A(t) on oversampled time grid."
function to_time!(Ato::Array{T, D}, Aω, Aωo, IFTplan) where T<:Real where D
    N = size(Aω, 1)
    No = size(Aωo, 1)
    scale = (No-1)/(N-1) # Scale factor makes up for difference in FFT array length
    fill!(Aωo, 0)
    copy_scale!(Aωo, Aω, N, scale)
    mul!(Ato, IFTplan, Aωo)
end

"Transform oversampled A(t) to A(ω) on normal grid."
function to_freq!(Aω, Aωo, Ato::Array{T, D}, FTplan) where T<:Real where D
    N = size(Aω, 1)
    No = size(Aωo, 1)
    scale = (N-1)/(No-1) # Scale factor makes up for difference in FFT array length
    mul!(Aωo, FTplan, Ato)
    copy_scale!(Aω, Aωo, N, scale)
end

"Copy first N elements from source to dest and simultaneously multiply by scale factor"
function copy_scale!(dest::Vector, source::Vector, N, scale)
    for i = 1:N
        dest[i] = scale * source[i]
    end
end

"copy_scale! for multi-dim arrays. Works along first axis"
function copy_scale!(dest, source, N, scale)
    (size(dest)[2:end] == size(source)[2:end] 
     || error("dest and source must be same size except along first dimension"))
    idcs = CartesianIndices((N, size(dest)[2:end]...))
    _cpsc_core(dest, source, scale, idcs)
end

function _cpsc_core(dest, source, scale, idcs)
    for i in idcs
        dest[i] = scale * source[i]
    end
end

"Normalisation factor for mode-averaged field."
function norm_mode_average(ω, βfun)
    out = zero(ω)
    function norm(z)
        out .= PhysData.c^2 .* PhysData.ε_0 .* βfun(ω, 1, 1, z) ./ ω
        return out
    end
    return norm
end

"Transform E(ω) -> Pₙₗ(ω) for mode-averaged field, i.e. only FT and inverse FT."
function trans_mode_avg(grid)
    Nto = length(grid.to)
    Nt = length(grid.t)

    Eωo = zeros(ComplexF64, length(grid.ωo))
    Eto = zeros(Float64, length(grid.to))
    Pto = similar(Eto)
    Pωo = similar(Eωo)

    FT = FFTW.plan_rfft(Eto)
    IFT = FFTW.plan_irfft(Eωo, Nto)

    function Pω!(Pω, Eω, z, responses)
        fill!(Pto, 0)
        to_time!(Eto, Eω, Eωo, IFT)
        for resp in responses
            resp(Pto, Eto)
        end
        @. Pto *= grid.towin
        to_freq!(Pω, Pωo, Pto, FT)
    end

    return Pω!
end

end