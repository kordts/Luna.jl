module Maths
import FiniteDifferences
import LinearAlgebra: Tridiagonal, mul!, ldiv!
import SpecialFunctions: erf, erfc
import StaticArrays: SVector
import Random: AbstractRNG, randn, MersenneTwister
import FFTW
import Luna.Utils: saveFFTwisdom, loadFFTwisdom
import Dierckx

"Calculate derivative of function f(x) at value x using finite differences"
function derivative(f, x, order::Integer)
    if order == 0
        return f(x)
    else
        # use 5th order central finite differences with 4 adaptive steps
        scale = abs(x) > 0 ? x : 1.0
        FiniteDifferences.fdm(FiniteDifferences.central_fdm(order+4, order), y->f(y*scale), x/scale, adapt=4)/scale^order
    end
end

"Gaussian or hypergaussian function (with std dev σ as input)"
function gauss(x, σ; x0 = 0, power = 2)
    return @. exp(-1//2 * ((x-x0)/σ)^power)
end

"Gaussian or hypergaussian function (with FWHM as input)"
function gauss(x; x0 = 0, power = 2, fwhm)
    σ = fwhm / (2 * (2 * log(2))^(1 / power))
    return gauss(x, σ, x0 = x0, power=power)
end

function randgauss(μ, σ, args...; seed=nothing)
    rng = MersenneTwister(seed)
    σ*randn(rng, args...) .+ μ
end

"nth moment of the vector y"
function moment(x::Vector, y::Vector, n = 1)
    if length(x) ≠ length(y)
        throw(DomainError(x, "x and y must have same length"))
    end
    return sum(x.^n .* y) / sum(y)
end

"nth moment of multi-dimensional array y along dimension dim"
function moment(x::Vector, y, n = 1; dim = 1)
    if size(y, dim) ≠ length(x)
        throw(DomainError(y, "y must be of same length as x along dim"))
    end
    xshape = ones(Integer, ndims(y))
    xshape[dim] = length(x)
    return sum(reshape(x, Tuple(xshape)).^n .* y, dims=dim) ./ sum(y, dims=dim)
end

"RMS width of distribution y on axis x"
function rms_width(x::Vector, y::Vector; dim = 1)
    return sqrt(moment(x, y, 2) - moment(x, y, 1)^2)
end

function rms_width(x::Vector, y; dim = 1)
    return sqrt.(moment(x, y, 2, dim = dim) - moment(x, y, 1, dim = dim).^2)
end

"""
Trapezoidal integration for multi-dimensional arrays, in-place or with output array.
In all of these functions, x can be an array (the x axis) or a number (the x axis spacing)

In-place integration for multi-dimensional arrays
"""
function cumtrapz!(y, x; dim=1)
    idxlo = CartesianIndices(size(y)[1:dim-1])
    idxhi = CartesianIndices(size(y)[dim+1:end])
    _cumtrapz!(y, x, idxlo, idxhi)
end

"Inner function for multi-dimensional arrays - uses 1-D routine internally"
function _cumtrapz!(y, x, idxlo, idxhi)
    for lo in idxlo
        for hi in idxhi
            cumtrapz!(view(y, lo, :, hi), x)
        end
    end
end

"In-place integration for 1-D arrays"
function cumtrapz!(y::T, x) where T <: Union{SubArray, Vector}
    tmp = y[1]
    y[1] = 0
    for i in 2:length(y)
        tmp2 = y[i]
        y[i] = y[i-1] + 1//2 * (tmp + tmp2) * _dx(x, i)
        tmp = tmp2
    end
end

"Integration into output array for multi-dimensional arrays"
function cumtrapz!(out, y, x; dim=1)
    idxlo = CartesianIndices(size(y)[1:dim-1])
    idxhi = CartesianIndices(size(y)[dim+1:end])
    _cumtrapz!(out, y, x, idxlo, idxhi)
end

"Inner function for multi-dimensional arrays - uses 1-D routine internally"
function _cumtrapz!(out, y, x, idxlo, idxhi)
    for lo in idxlo
        for hi in idxhi
            cumtrapz!(view(out, lo, :, hi), view(y, lo, :, hi), x)
        end
    end
end

"Integration into output array for 1-D array"
function cumtrapz!(out, y::Union{SubArray, Vector}, x)
    out[1] = 0
    for i in 2:length(y)
        out[i] = out[i-1]+ 1//2*(y[i-1] + y[i])*_dx(x, i)
    end
end

"x axis spacing if x is given as an array"
function _dx(x, i)
    x[i] - x[i-1]
end

"x axis spacing if x is given as a number (i.e. dx)"
function _dx(x::Number, i)
    x
end

function cumtrapz(y, x; dim=1)
    out = similar(y)
    cumtrapz!(out, y, x; dim=dim) 
    return out
end

"Normalise an array by its maximum value"
function normbymax(x, dims)
    return x ./ maximum(x; dims = dims)
end

function normbymax(x)
    return x ./ maximum(x)
end

"Normalised log10 i.e. maximum of output is 0"
function log10_norm(x)
    return log10.(normbymax(x))
end

function log10_norm(x, dims)
    return log10.(normbymax(x, dims = dims))
end

"Window based on the error function"
function errfun_window(x, xmin, xmax, width)
    return @. 0.5 * (erf((x - xmin) / width) + erfc((x - xmax) / width) - 1)
end

"Error function window but with different widths on each side"
function errfun_window(x, xmin, xmax, width_left, width_right)
    return @. 0.5 * (erf((x - xmin) / width_left) + erfc((x - xmax) / width_right) - 1)
end

"""
Planck taper window as defined in the paper (https://arxiv.org/pdf/1003.2939.pdf eq(7)):
    xmin: lower limit (window is 0 here)
    xmax: upper limit (window is 0 here)
    ε: fraction of window width over which to increase from 0 to 1
"""
function planck_taper(x::AbstractArray, xmin, xmax, ε)
    x0 = (xmax + xmin) / 2
    xc = x .- x0
    X = (xmax - xmin)
    x1  = -X / 2
    x2 = -X / 2 * (1 - 2ε)
    x3 = X / 2 * (1 - 2ε)
    x4 = X / 2
    return _taper(xc, x1, x2, x3, x4)
end

"""
Planck taper window, but finding the taper width by defining 4 points:
The window increases from 0 to 1 between left0 and left1, and then drops again
to 0 between right1 and right0
"""
function planck_taper(x::AbstractArray, left0, left1, right1, right0)
    x0 = (right0 + left0) / 2
    xc = x .- x0
    X = right0 - left0
    εleft = abs(left1 - left0) / X
    εright = abs(right0 - right1) / X
    x1  = -X / 2
    x2 = -X / 2 * (1 - 2εleft)
    x3 = X / 2 * (1 - 2εright)
    x4 = X / 2
    return _taper(xc, x1, x2, x3, x4)
end

"""
Planck taper helper function, common to both versions of planck_taper
"""
function _taper(xc, x1, x2, x3, x4)
    idcs12 = x1 .< xc .< x2
    idcs23 = x2 .<= xc .<= x3
    idcs34 = x3 .< xc .< x4
    z12 = @. (x2 - x1) / (xc[idcs12] - x1) + (x2 - x1) / (xc[idcs12] - x2)
    z34 = @. (x3 - x4) / (xc[idcs34] - x3) + (x3 - x4) / (xc[idcs34] - x4)
    out = zero(xc)
    @. out[idcs12] = 1 / (1 + exp(z12))
    @. out[idcs23] = 1
    @. out[idcs34] = 1 / (1 + exp(z34))
    return out
end

"""
Hypergaussian window
"""
function hypergauss_window(x, xmin, xmax, power = 10)
    fw = xmax - xmin
    x0 = (xmax + xmin) / 2
    return gauss(x, x0 = x0, fwhm = fw, power = power)
end

"""
    hilbert(x; dim=1)

Compute the Hilbert transform, i.e. find the analytic signal from a real signal.
"""
function hilbert(x::Array{T,N}; dim = 1) where T <: Real where N
    xf = FFTW.fft(x, dim)
    n1 = size(xf, dim)÷2
    n2 = size(xf, dim)
    idxlo = CartesianIndices(size(xf)[1:dim - 1])
    idxhi = CartesianIndices(size(xf)[dim + 1:end])
    xf[idxlo, 2:n1, idxhi] .*= 2
    xf[idxlo, (n1+1):n2, idxhi] .= 0
    return FFTW.ifft(xf, dim)
end

"""
    plan_hilbert!(x; dim=1)

Pre-plan a Hilbert transform.

Returns a closure `hilbert!(out, x)` which places the Hilbert transform of `x` in `out`.
"""
function plan_hilbert!(x; dim=1)
    loadFFTwisdom()
    FT = FFTW.plan_fft(x, dim, flags=FFTW.PATIENT)
    saveFFTwisdom()
    xf = Array{ComplexF64}(undef, size(FT))
    idxlo = CartesianIndices(size(xf)[1:dim - 1])
    idxhi = CartesianIndices(size(xf)[dim + 1:end])
    n1 = size(xf, dim)÷2
    n2 = size(xf, dim)
    xc = complex(x)
    function hilbert!(out, x)
        copyto!(xc, x)
        mul!(xf, FT, xc)
        xf[idxlo, 2:n1, idxhi] .*= 2
        xf[idxlo, (n1+1):n2, idxhi] .= 0
        ldiv!(out, FT, xf)
    end
    return hilbert!
end

"""
    plan_hilbert(x; dim=1)

Pre-plan a Hilbert transform.

Returns a closure `hilbert(x)` which returns the Hilbert transform of `x` without allocation.

!!! warning
    The closure returned always returns a reference to the same array buffer, which could lead
    to unexpected results if it is called from more than one location. To avoid this the array
    should either: (i) only be used in the same code segment; (ii) only be used transiently
    as part of a larger computation; (iii) copied.
"""
function plan_hilbert(x; dim=1)
    out = complex(x)
    hilbert! = plan_hilbert!(x, dim=dim)
    function hilbert(x)
        hilbert!(out, x)
    end
    return hilbert
end

"""
Oversample (smooth) an array by 0-padding in the frequency domain
"""
function oversample(t, x::Array{T,N}; factor::Integer = 4, dim = 1) where T <: Real where N
    if factor == 1
        return t, x
    end
    xf = FFTW.rfft(x, dim)

    len = size(xf, dim)
    newlen_t = factor * length(t)
    if iseven(newlen_t)
        newlen_ω = Int(newlen_t / 2 + 1)
    else
        newlen_ω = Int((newlen_t + 1) / 2)
    end
    δt = t[2] - t[1]
    δto = δt / factor
    Nto = collect(0:newlen_t - 1)
    to = t[1] .+ Nto .* δto

    shape = collect(size(xf))
    shape[dim] = newlen_ω
    xfo = zeros(eltype(xf), Tuple(shape))
    idxlo = CartesianIndices(size(xfo)[1:dim - 1])
    idxhi = CartesianIndices(size(xfo)[dim + 1:end])
    xfo[idxlo, 1:len, idxhi] .= factor .* xf
    return to, FFTW.irfft(xfo, newlen_t, dim)
end

"""
Oversampling for complex-valued arryas (e.g. envelope fields)
"""
function oversample(t, x::Array{T,N}; factor::Integer = 4, dim = 1) where T <: Complex where N
    if factor == 1
        return t, x
    end
    xf = FFTW.fftshift(FFTW.fft(x, dim), dim)

    len = size(xf, dim)
    newlen = factor * length(t)
    δt = t[2] - t[1]
    δto = δt / factor
    Nto = collect(0:newlen - 1)
    to = t[1] .+ Nto .* δto

    sidx  = (newlen - len)//2 + 1
    iseven(newlen) || (sidx -= 1//2)
    iseven(len) || (sidx += 1//2)
    startidx = Int(sidx)
    endidx = startidx+len-1

    shape = collect(size(xf))
    shape[dim] = newlen
    xfo = zeros(eltype(xf), Tuple(shape))
    idxlo = CartesianIndices(size(xfo)[1:dim - 1])
    idxhi = CartesianIndices(size(xfo)[dim + 1:end])
    xfo[idxlo, startidx:endidx, idxhi] .= factor .* xf
    return to, FFTW.ifft(FFTW.ifftshift(xfo, dim), dim)
end


"""
Find limit of a series by Aitken acceleration
"""
function aitken_accelerate(f, x0; n0 = 0, rtol = 1e-6, maxiter = 10000)
    n = n0
    x0 = f(x0, n)
    x1 = f(x0, n + 1)
    x2 = f(x1, n + 2)
    Ax = aitken(x0, x1, x2)
    success = false
    while ~success && n < maxiter
        n += 1
        Axprev = Ax
        x0 = x1
        x1 = x2
        x2 = f(x2, n + 2)
        Ax = aitken(x0, x1, x2)

        if 2 * abs(Ax - Axprev) / abs(Ax + Axprev) < rtol
            success = true
        end
    end
    return Ax, success, n
end

function aitken(x0, x1, x2)
    den = (x0 - x1) - (x1 - x2)
    return x0 - (x1 - x0)^2 / den
end

"""
Find limit of series by brute force
"""
function converge_series(f, x0; n0 = 0, rtol = 1e-6, maxiter = 10000)
    n = n0
    x1 = x0
    success = false
    while ~success && n < maxiter
        x1 = f(x0, n)

        if 2 * abs(x1 - x0) / abs(x1 + x0) < rtol
            success = true
        end

        n += 1
        x0 = x1
    end
    return x1, success, n
end

"""
    CSpline

Simple cubic spline, see e.g.:
http://mathworld.wolfram.com/CubicSpline.html Boundary        
conditions extrapolate with initially constant gradient
"""
struct CSpline{Tx,Ty,Vx<:AbstractVector{Tx},Vy<:AbstractVector{Ty}, fT}
    x::Vx
    y::Vy
    D::Vy
    ifun::fT
end

# make  broadcast like a scalar
Broadcast.broadcastable(c::CSpline) = Ref(c)

"""
    CSpline(x, y [, ifun])

Construct a `CSpline` to interpolate the values `y` on axis `x`.

If given, `ifun(x0)` should return the index of the first element in x which is bigger
than x0. Otherwise, it defaults two one of two options:
1. If `x` is uniformly spaced, the index is calculated based on the spacing of `x`
2. If `x` is not uniformly spaced, a `FastFinder` is used instead.
"""
function CSpline(x, y, ifun=nothing)
    if any(diff(x) .== 0)
        error("entries in x must be unique")
    end
    if !issorted(x)
        idcs = sortperm(x)
        x = x[idcs]
        y = y[idcs]
    end
    R = similar(y)
    R[1] = y[2] - y[1]
    for i in 2:(length(y)-1)
        R[i] = y[i+1] - y[i-1]
    end
    R[end] = y[end] - y[end - 1]
    @. R *= 3
    d = fill(4.0, size(y))
    d[1] = 2.0
    d[end] = 2.0
    dl = fill(1.0, length(y) - 1)
    M = Tridiagonal(dl, d, dl)
    D = M \ R
    if ifun === nothing
        δx = x[2] - x[1]
        if all(diff(x) .≈ δx)
            # x is uniformly spaced - use fast lookup
            xmax = maximum(x)
            xmin = minimum(x)
            N = length(x)
            ffast(x0) = x0 <= xmin ? 2 :
                        x0 >= xmax ? N : 
                        ceil(Int, (x0-xmin)/(xmax-xmin)*(N-1))+1
            ifun = ffast
        else
            # x is not uniformly spaced - use brute-force lookup
            ifun = FastFinder(x)
        end
    end
    CSpline(x, y, D, ifun)
end

"""
    (c::CSpline)(x0)

Evaluate the `CSpline` at coordinate `x0`
"""
function (c::CSpline)(x0)
    i = c.ifun(x0)
    x0 == c.x[i] && return c.y[i]
    x0 == c.x[i-1] && return c.y[i-1]
    t = (x0 - c.x[i - 1])/(c.x[i] - c.x[i - 1])
    (c.y[i - 1] 
        + c.D[i - 1]*t 
        + (3*(c.y[i] - c.y[i - 1]) - 2*c.D[i - 1] - c.D[i])*t^2 
        + (2*(c.y[i - 1] - c.y[i]) + c.D[i - 1] + c.D[i])*t^3)
end

"""
    FastFinder

Callable type which accelerates index finding for the case where inputs are usually in order.
"""
mutable struct FastFinder{xT, xeT}
    x::xT
    mi::xeT
    ma::xeT
    N::Int
    ilast::Int
    xlast::xeT
end

"""
    FastFinder(x)

Construct a `FastFinder` to find indices in the array `x`.

!!! warning
    `x` must be sorted in ascending order for `FastFinder` to work.
"""
function FastFinder(x::AbstractArray)
    issorted(x) || error("Input array for FastFinder must be sorted in ascending order.")
    if any(diff(x) .== 0)
        error("Entries in input array for FastFinder must be unique.")
    end
    FastFinder(x, x[1], x[end], length(x), 0, typemin(x[1]))
end

"""
    (f::FastFinder)(x0)

Find the first index in `f.x` which is larger than `x0`.

This is similar to [`findfirst`](@ref), but it starts at the index which was last used.
If the new value `x0` is close to the previous `x0`, this is much faster than `findfirst`.
"""
function (f::FastFinder)(x0::Number)
    # Default cases if we're out of bounds
    if x0 <= f.x[1]
        f.xlast = x0
        f.ilast = 1
        return 2
    elseif x0 >= f.x[end]
        f.xlast = x0
        f.ilast = f.N
        return f.N
    end
    if f.ilast == 0 # first call -- f.xlast is not set properly so comparisons won't work
        # return using brute-force method instead
        f.ilast = findfirst(x -> x>x0, f.x)
        return f.ilast
    end
    if x0 == f.xlast # same value as before - no work to be done
        return f.ilast
    elseif x0 < f.xlast # smaller than previous value - go through array backwards
        f.xlast = x0
        for i = f.ilast:-1:1
            if f.x[i] < x0
                f.ilast = i+1 # found last idx where x < x0 -> at i+1, x > x0
                return i+1
            end
        end
        # we only get to this point if we haven't found x0 - return the lower bound (2)
        f.ilast = 1
        return 2
    else # larger than previous value - just pick up where we left off
        f.xlast = x0
        for i = f.ilast:f.N
            if f.x[i] > x0
                f.ilast = i
                return i
            end
        end
        # we only get to this point if we haven't found x0 - return the upper bound (N)
        f.ilast = f.N
        return f.N
    end
end

struct RealSpline{sT}
    rspl::sT
end

struct CmplxSpline{sT}
    rspl::sT
    ispl::sT
end

Broadcast.broadcastable(rs::RealSpline) = Ref(rs)
Broadcast.broadcastable(cs::CmplxSpline) = Ref(cs)

"""
    spline(x, y)

Construct a `RealSpline` or `CmplxSpline` to interpolate the values `y` on axis `x`.

"""
function spline(x::AbstractVector, y::AbstractVector{T}) where T <: Complex
    CmplxSpline(Dierckx.Spline1D(x, real(y), bc="extrapolate", k=3, s=0.0),
                Dierckx.Spline1D(x, imag(y), bc="extrapolate", k=3, s=0.0))
end

function spline(x::AbstractVector, y::AbstractVector{T}) where T <: Real
    RealSpline(Dierckx.Spline1D(x, real(y), bc="extrapolate", k=3, s=0.0))
end

"""
    (cs::CmplxSpline)(x)

Evaluate the `CmplxSpline` at coordinate(s) `x`
"""
function (cs::CmplxSpline)(x; )
    complex.(cs.rspl(x), cs.ispl(x))
end

"""
    (cs::RealSpline)(x)

Evaluate the `RealSpline` at coordinate(s) `x`
"""
function (rs::RealSpline)(x)
    rs.rspl(x)
end

"""
    derivative(rs::RealSpline, x, order::Integer)

Calculate derivative of the spline `rs`. For `order == 1` this uses an optimised routine.
For `order > 1` this falls back to the generic finite difference based method.
"""
function derivative(rs::RealSpline, x, order::Integer)
    if order == 0
        return rs(x)
    elseif order == 1
        return Dierckx.derivative(rs.rspl, x )
    else
        invoke(derivative, Tuple{Any,Any,Integer}, rs, x, order)
    end
end

"""
    derivative(cs::CmplxSpline, x, order::Integer)

Calculate derivative of the spline `cs`. For `order == 1` this uses an optimised routine.
For `order > 1` this falls back to the generic finite difference based method.
"""
function derivative(cs::CmplxSpline, x, order::Integer)
    if order == 0
        return cs(x)
    elseif order == 1
        return complex.(Dierckx.derivative(cs.rspl, x ), Dierckx.derivative(cs.ispl, x ))
    else
        invoke(derivative, Tuple{Any,Any,Integer}, cs, x, order)
    end
end

"""
    roots(rs::RealSpline)

Find the roots of the spline `rs`.
"""
function roots(rs::RealSpline)
    Dierckx.roots(rs.rspl)
end

end
