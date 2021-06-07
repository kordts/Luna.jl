import Test: @test, @testset, @test_throws
import FunctionZeros: besselj_zero
import SpecialFunctions: besselj
import LinearAlgebra: norm
import FFTW
import Luna: Modes, Maths, Capillary, Grid, PhysData, Hankel, NonlinearRHS, Fields
import Luna.PhysData: wlfreq


@testset "delegation" begin
    m = Modes.delegated(Capillary.MarcatilliMode(75e-6, :He, 5.9))
    @test Modes.Aeff(m) ≈ 8.42157534886545e-09
    @test abs(1e9*Modes.zdw(m) - 562) < 1
    n(m, ω; z=0) = real(Modes.neff(m, ω; z=z))
    m2 = Modes.delegated(Capillary.MarcatilliMode(75e-6, :He, 1.0), neff=n)
    @test Modes.α(m2, 2e15) == 0
    @test Modes.α(m2, wlfreq(800e-9)) == 0

    cm = Capillary.MarcatilliMode(75e-6, :He, 5.9)
    dm = Modes.delegated(cm)
    @test Modes.Aeff(dm) ≈ 8.42157534886545e-09
    
    dm = Modes.delegated(cm, Aeff=(m; z=0) -> 0.5)
    @test Modes.Aeff(dm) == 0.5
    @test Modes.N(dm) == Modes.N(m)
    @test Modes.β(dm, 2e15) == Modes.β(m, 2e15)

    # fully delegated test
    n(ω; z=0) = 1.0 + 3.0im
    m3 = Modes.arbitrary(neff=n,
                         dimlimits=(;z=0)->(:polar, (0.0, 0.0), (100e-6, 2π)),
                         Aeff=(;z=0) -> 1e-5,
                         N=(;z=0) -> 1)
    @test Modes.α(m3, 1.5e15) == 2*3*1.5e15/PhysData.c
    @test Modes.β(m3, 1.5e15) == 1.5e15/PhysData.c
    @test Modes.Aeff(m3) == 1e-5
    @test Modes.N(m3) == 1
    @test_throws ErrorException Modes.field(m3, (0.0, 0.0))

    m4 = Modes.arbitrary(neff=Modes.neff_from_αβ((ω; z=0) -> 6*ω/PhysData.c,
                                                 (ω; z=0) -> ω/PhysData.c))
    @test Modes.α(m4, 1.5e15) ≈ 2*3*1.5e15/PhysData.c
    @test Modes.β(m4, 1.5e15) ≈ 1.5e15/PhysData.c
    @test Modes.neff(m4, 1.5e15) ≈ 1.0 + 3.0im
    @test Modes.neff(m4, 1.5e15) ≈ 1.0 + 3.0im
end

@testset "overlap" begin
a = 100e-6
m = Capillary.MarcatilliMode(a, :He, 1.0, model=:reduced)
r = collect(range(0, a, length=2^16))
unm = besselj_zero(0, 1)
Er = besselj.(0, unm*r/a) # spatial profile of the HE11 mode - overlap should be perfect
η = Modes.overlap(m, r, Er; dim=1)
@test abs2(η[1]) ≈ 1
unm = besselj_zero(0, 2)
Er = besselj.(0, unm*r/a) # spatial profile of HE12 - overlap should be 0
η = Modes.overlap(m, r, Er; dim=1)
@test isapprox(abs2(η[1]), 0, atol=1e-18)
# Check that we reproduce the optimal coupling for Gaussian beams at w₀ = 0.64a
fac = collect(range(0.3, stop=0.9, length=128))
ηn = zero(fac)
r = collect(range(0, 4a, length=2^16))
m = Capillary.MarcatilliMode(a, :He, 1.0, model=:reduced, m=1)
for i in eachindex(fac)
    w0 = fac[i]*a
    Er = Maths.gauss.(r, w0/sqrt(2))
    ηn[i] = abs2.(Modes.overlap(m, r, Er, dim=1)[1])
end
@test 0.63 < fac[argmax(ηn)] < 0.65

#= Testing that the sum of all modes is 1, i.e. the normalised overlap preserves the
    total energy =#
fac = 0.45
w0 = fac*a
Er = Maths.gauss.(r, w0/sqrt(2))
s = 0
for mi = 1:10
    m = Capillary.MarcatilliMode(a, :He, 1.0, model=:reduced, m=mi)
    η = Modes.overlap(m, r, Er, dim=1)[1]
    s += abs2(η[1])
end
@test isapprox(s, 1, rtol=1e-4)

#= Testing non-normalised overlap integrals. First we create a spatial field that consists
    of two pulses: one 30 fs pulse at 800 nm with the spatial shape of the HE11 mode,
    and one 15 fs pulse at 400 nm with the spatial shape of the HE12 mode. 
    We then calculate the non-normalised overlap integral of this spatial field with
    the HE11 and HE12 modes of a capillary and check that we reproduce the pulses that we
    put in at the beginning, as well as their energy. =#
a = 100e-6 # capillary radius
# spatial grid, with a bigger aperture than the capillary - as we would have in a simulation
q = Hankel.QDHT(2a, 512)
grid = Grid.RealGrid(1, 800e-9, (200e-9, 2000e-9), 0.5e-12)
# First pulse
It1 = Maths.gauss.(grid.t, fwhm=30e-15)
Et1 = @. sqrt(It1)*cos(2π*PhysData.c/800e-9*grid.t)
Eω1 = FFTW.rfft(Et1)
# Spatial profile of the first pulse
unm = besselj_zero(0, 1)
Er1 = besselj.(0, unm*q.r/a)'
Er1[q.r .> a] .= 0
Etr1 = Et1 .* Er1 # create spatio-temporal pulse profile
# Second pulse
It2 = 4*Maths.gauss.(grid.t, fwhm=15e-15)
Et2 = @. sqrt(It2)*cos(2π*PhysData.c/400e-9*grid.t)
Eω2 = FFTW.rfft(Et2)
# Spatial profile of the second pulse
unm = besselj_zero(0, 2)
Er2 = besselj.(0, unm*q.r/a)'
Er2[q.r .> a] .= 0
Etr2 = Et2 .* Er2 # create spatio-temporal pulse profile

# The total spatio-temporal field is the sum of the two pulses
Etr = Etr1 .+ Etr2
Eωr = FFTW.rfft(Etr, 1)

ert, ekω = Fields.energyfuncs(grid, q)
energy1 = ert(Etr1)
energy2 = ert(Etr2)
@test ert(Etr) ≈ energy1 + energy2

m1 = Capillary.MarcatilliMode(a, :He, 1.0, model=:reduced, m=1)
m2 = Capillary.MarcatilliMode(a, :He, 1.0, model=:reduced, m=2)
Eωm1 = Modes.overlap(m1, q.r, Eωr; dim=2, norm=false)
Eωm2 = Modes.overlap(m2, q.r, Eωr; dim=2, norm=false)

Etm1 = FFTW.irfft(Eωm1[:, 1], length(grid.t))
Etm2 = FFTW.irfft(Eωm2[:, 1], length(grid.t))

et, eω = Fields.energyfuncs(grid)
# check that the non-normalised overlap integral preserves the total energy
@test isapprox(et(Etm1), energy1, rtol=1e-3)
@test isapprox(et(Etm2), energy2, rtol=1e-3)

# check that the non-normalised overlap integral preserves the spectral shape
En1 = Eω1/norm(Eω1)
Emn1 = Eωm1/norm(Eωm1)
@test all(isapprox.(En1, Emn1, atol=1e-3*maximum(abs.(Emn1))))

En2 = Eω2/norm(Eω2)
Emn2 = Eωm2/norm(Eωm2)
@test all(isapprox.(En2, Emn2, atol=1e-3*maximum(abs.(Emn2))))
end

@testset "overlap with interpolation" begin
#= Here we test the complete decomposition of a field into two modes while also re-gridding
    onto a new time grid. We create two pulses in different spatial modes with different
    arrival times and durations on one grid and check that we reproduce them on a new grid.
    =#
a = 100e-6 # capillary radius
# spatial grid, with a bigger aperture than the capillary - as we would have in a simulation
q = Hankel.QDHT(2a, 512)
grid = Grid.RealGrid(1, 800e-9, (400e-9, 1000e-9), 0.5e-12)

fwhm1 = 30e-15
τ1 = -5e-15
fwhm2 = 15e-15
τ2 = 10e-15

# First pulse
It1 = Maths.gauss.(grid.t, x0=τ1, fwhm=fwhm1)
Et1 = @. sqrt(It1)*cos(2π*PhysData.c/800e-9*grid.t)
Eω1 = FFTW.rfft(Et1)
# Spatial profile of the first pulse
unm = besselj_zero(0, 1)
Er1 = besselj.(0, unm*q.r/a)'
Er1[q.r .> a] .= 0
Etr1 = Et1 .* Er1 # create spatio-temporal pulse profile
# Second pulse
It2 = 4*Maths.gauss.(grid.t, x0=τ2, fwhm=fwhm2)
Et2 = @. sqrt(It2)*cos(2π*PhysData.c/800e-9*grid.t)
Eω2 = FFTW.rfft(Et2)
# Spatial profile of the second pulse
unm = besselj_zero(0, 2)
Er2 = besselj.(0, unm*q.r/a)'
Er2[q.r .> a] .= 0
Etr2 = Et2 .* Er2 # create spatio-temporal pulse profile

# The total spatio-temporal field is the sum of the two pulses
Etr = Etr1 .+ Etr2
Eωr = FFTW.rfft(Etr, 1)

ert, ekω = Fields.energyfuncs(grid, q)
energy1 = ert(Etr1)
energy2 = ert(Etr2)
@test ert(Etr) ≈ energy1 + energy2

modes = (Capillary.MarcatilliMode(a, :He, 1.0, model=:reduced, m=1),
         Capillary.MarcatilliMode(a, :He, 1.0, model=:reduced, m=2))
newgrid = Grid.RealGrid(1, 800e-9, (160e-9, 3000e-9), 1e-12)

Eωm = Modes.overlap(modes, newgrid, grid, q.r, Eωr)

et, eω = Fields.energyfuncs(newgrid)
# do we preserve the energy?
@test isapprox(eω(Eωm[:, 1]), energy1, rtol=1e-3)
@test isapprox(eω(Eωm[:, 2]), energy2, rtol=1e-3)

Etm = FFTW.irfft(Eωm, length(newgrid.t), 1)
Itm = abs2.(Maths.hilbert(Etm))
# is fwhm the same?
@test isapprox(Maths.fwhm(newgrid.t, Itm[:, 1]), fwhm1, rtol=1e-4)
@test isapprox(Maths.fwhm(newgrid.t, Itm[:, 2]), fwhm2, rtol=1e-4)
# do we preserve the temporal location?
@test abs(newgrid.t[argmax(Itm[:, 1])] - τ1) < (newgrid.t[2]-newgrid.t[1])
@test isapprox(Maths.moment(newgrid.t, Itm[:, 1]), τ1, rtol=1e-3)
@test abs(newgrid.t[argmax(Itm[:, 2])] - τ2) < (newgrid.t[2]-newgrid.t[1])
@test isapprox(Maths.moment(newgrid.t, Itm[:, 2]), τ2, rtol=1e-3)

# are the temporal shapes reproduced?
It1new = Maths.gauss.(newgrid.t, x0=τ1, fwhm=fwhm1)
It1new /= norm(It1new)
Itm1 = Itm[:, 1]/norm(Itm[:, 1])
@test all(isapprox.(Itm1, It1new, atol=1e-3*maximum(abs.(It1new))))

It2new = Maths.gauss.(newgrid.t, x0=τ2, fwhm=fwhm2)
It2new /= norm(It2new)
Itm2 = Itm[:, 2]/norm(Itm[:, 2])
@test all(isapprox.(Itm2, It2new, atol=1e-3*maximum(abs.(It2new))))
end

##
@testset "Orthogonality" begin
a = 100e-6
m1 = Capillary.MarcatilliMode(a; n=1, m=1)
m2 = Capillary.MarcatilliMode(a; n=1, m=2)
@test Modes.overlap(m1, m1) ≈ 1
@test isapprox(Modes.overlap(m1, m2), 0; atol=1e-10)
@test Modes.orthonormal((m1, m2))
# Capillary EH modes are all orthonormal
mm = collect([Capillary.MarcatilliMode(a; n=1, m=mi) for mi=1:5])
@test Modes.orthonormal(mm)
# Two identical modes in the list - not a valid basis set
@test !Modes.orthonormal([mm..., m1])

m1 = Capillary.MarcatilliMode(a)
m2 = Capillary.MarcatilliMode(a; ϕ=π/2)
@test isapprox(Modes.overlap(m1, m2), 0; atol=1e-10)

m2 = Capillary.MarcatilliMode(2a; ϕ=π/2)
@test_throws ErrorException Modes.overlap(m1, m2)
end