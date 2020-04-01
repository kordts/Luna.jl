module Output
import HDF5
import Logging
import Base: getindex, show
import Printf: @sprintf
import Luna: Scans, Utils, @hlock


"Output handler for writing only to memory"
mutable struct MemoryOutput{sT, N, S}
    save_cond::sT
    ydims::NTuple{N, Int64}  # Dimensions of one array to be saved
    yname::AbstractString  # Name for solution (e.g. "Eω")
    tname::AbstractString  # Name for propagation direction (e.g. "z")
    saved::Integer  # How many points have been saved so far
    data::Dict{String, Any}  # The actual data
    statsfun::S  # Callable, returns dictionary of statistics
end

function MemoryOutput(tmin, tmax, saveN::Integer, ydims, statsfun=nostats;
                      yname="Eω", tname="z", script=nothing)
    save_cond = GridCondition(tmin, tmax, saveN)
    MemoryOutput(save_cond, ydims, yname, tname, statsfun, script)
end

function MemoryOutput(save_cond, ydims, yname, tname, statsfun=nostats, script=nothing)
    dims = init_dims(ydims, save_cond)
    data = Dict{String, Any}()
    data[yname] = Array{ComplexF64}(undef, dims)
    data[tname] = Array{Float64}(undef, (dims[end],))
    data["stats"] = Dict{String, Any}()
    data["meta"] = Dict{String, Any}()
    data["meta"]["sourcecode"] = Utils.sourcecode()
    data["meta"]["git_commit"] = Utils.git_commit()
    if !isnothing(script)
        data["meta"]["script_code"] = script
    end
    MemoryOutput(save_cond, ydims, yname, tname, 0, data, statsfun)
end

"getindex works interchangeably so when switching from one Output to
another, subsequent code can stay the same"
getindex(o::MemoryOutput, idx) = o.data[idx]

show(io::IO, o::MemoryOutput) = print(io, "MemoryOutput$(collect(keys(o.data)))")

"""Calling the output handler saves data in the arrays
    Arguments:
        y: current function value
        t: current propagation point
        dt: current stepsize
        yfun: callable which returns interpolated function value at different t
    Note that from RK45.jl, this will be called with yn and tn as arguments.
"""
function (o::MemoryOutput)(y, t, dt, yfun)
    save, ts = o.save_cond(y, t, dt, o.saved)
    # append_stats!(o, o.statsfun(y, t, dt))
    while save
        s = size(o.data[o.yname])
        if s[end] < o.saved+1
            o.data[o.yname] = fastcat(o.data[o.yname], yfun(ts))
            push!(o.data[o.tname], ts)
        else
            idcs = fill(:, length(o.ydims))
            o.data[o.yname][idcs..., o.saved+1] = yfun(ts)
            o.data[o.tname][o.saved+1] = ts
        end
        o.saved += 1
        save, ts = o.save_cond(y, t, dt, o.saved)
    end
end

function (o::MemoryOutput)(yk, yx, t, dt, yfun)
    append_stats!(o, o.statsfun(yk, yx, t, dt))
    o(yk, t, dt, yfun)
end

function append_stats!(o::MemoryOutput, d)
    for (k, v) in pairs(d)
        append_stat!(o, k, v)
    end
end

function append_stat!(o::MemoryOutput, name, value::Number)
    if ~haskey(o.data["stats"], name)
        o.data["stats"][name] = [value]
    else
        push!(o.data["stats"][name], value)
    end
end

function append_stat!(o::MemoryOutput, name, value::AbstractArray)
    if ~haskey(o.data["stats"], name)
        dims = size(value)
        o.data["stats"][name] = reshape(value, (size(value)..., 1))
    else
        o.data["stats"][name] = fastcat(o.data["stats"][name], value)
    end
end

"Calling the output on a dictionary writes the items to the array"
function (o::MemoryOutput)(d::Dict; force=false, meta=false, group=nothing)
    for (k, v) in pairs(d)
        o(k, v; force=force, meta=meta, group=group)
    end
end

"Calling the output with a key, value pair writes the value to the array."
function (o::MemoryOutput)(key::AbstractString, val; force=false, meta=false, group=nothing)
    parent = meta ? o.data["meta"] : o.data
    if haskey(parent, key)
            if force
                Logging.@warn("Key $key already exists and will be overwritten.")
            else
                error("Key $key already present in dataset.")
        end
    end
    if !isnothing(group)
        if !haskey(parent, group)
            parent[group] = Dict{String, Any}()
        end
        parent[group][key] = val
    else
        parent[key] = val
    end
end

function tofile(fpath, o::MemoryOutput)
    Utils.save_dict_h5(fpath, o.data)
end

function fastcat(A, v)
    Av = vec(A)
    append!(Av, vec(v))
    dims = size(A)
    return reshape(Av, (dims[1:end-1]..., dims[end]+1))
end

"Output handler for writing to an HDF5 file"
mutable struct HDF5Output{sT, N, S}
    fpath::AbstractString  # Path to output file
    save_cond::sT  # callable, determines when data is saved and where it is interpolated
    ydims::NTuple{N, Int64}  # Dimensions of one array to be saved
    yname::AbstractString  # Name for solution (e.g. "Eω")
    tname::AbstractString  # Name for propagation direction (e.g. "z")
    saved::Integer  # How many points have been saved so far
    statsfun::S  # Callable, returns dictionary of statistics
    stats_tmp::Vector{Dict{String, Any}}  # Temporary storage for statistics between saves
end

"Simple constructor"
function HDF5Output(fpath, tmin, tmax, saveN::Integer, ydims, statsfun=nostats;
                    yname="Eω", tname="z", compression=false, script=nothing)
    save_cond = GridCondition(tmin, tmax, saveN)
    HDF5Output(fpath, save_cond, ydims, yname, tname, statsfun, compression, script)
end

"Internal constructor - creates datasets in the file"
function HDF5Output(fpath, save_cond, ydims, yname, tname, statsfun, compression, script=nothing)
    idims = init_dims(ydims, save_cond)
    cdims = collect(idims)
    # cdims[1] *= 2 # Allow for interleaving of real, imag, real, imag...
    dims = Tuple(cdims)
    chdims = (dims[1:end-1]..., 1) # Chunk size is that of one z-point
    mdims = copy(cdims)
    mdims[end] = -1
    maxdims = Tuple(mdims)
    if isfile(fpath)
        Logging.@warn("Output file $(fpath) already exists and will be overwritten!")
        rm(fpath)
    end
    fdir, fname = splitdir(fpath)
    isdir(fdir) || mkpath(fdir)
    @hlock HDF5.h5open(fpath, "cw") do file
        if compression
            HDF5.d_create(file, yname, HDF5.datatype(ComplexF64), (dims, maxdims),
                          "chunk", chdims, "blosc", 3)
        else
            HDF5.d_create(file, yname, HDF5.datatype(ComplexF64), (dims, maxdims),
                          "chunk", chdims)
        end
        HDF5.d_create(file, tname, HDF5.datatype(Float64), ((dims[end],), (-1,)),
                      "chunk", (1,))
        HDF5.g_create(file, "stats")
        HDF5.g_create(file, "meta")
        file["meta"]["sourcecode"] = Utils.sourcecode()
        file["meta"]["git_commit"] = Utils.git_commit()
        if !isnothing(script)
            file["meta"]["script_code"] = script
        end
    end
    stats0 = Vector{Dict{String, Any}}()
    HDF5Output(fpath, save_cond, ydims, yname, tname, 0, statsfun, stats0)
end

"Here, getindex also opens and closes the file.
Note that if file[idx] is a group, HDF5 automatically converts this
to a Dict"
function getindex(o::HDF5Output, idx)
    ret = @hlock HDF5.h5open(o.fpath, "r") do file
        read(file[idx])
    end
    return ret
end

function show(io::IO, o::HDF5Output)
    fields = @hlock HDF5.h5open(o.fpath) do file
        names(file)
    end
    print(io, "HDF5Output$(fields)")
end


"""Calling the output handler writes data to the file
    Arguments:
        y: current function value
        t: current propagation point
        dt: current stepsize
        yfun: callable which returns interpolated function value at different t
    Note that from RK45.jl, this will be called with yn and tn as arguments.
"""
function (o::HDF5Output)(y, t, dt, yfun)
    save, ts = o.save_cond(y, t, dt, o.saved)
    push!(o.stats_tmp, o.statsfun(y, t, dt))
    if save
        @hlock HDF5.h5open(o.fpath, "r+") do file
            while save
                idcs = fill(:, length(o.ydims))
                s = collect(size(file[o.yname]))
                if s[end] < o.saved+1
                    s[end] += 1
                    HDF5.set_dims!(file[o.yname], Tuple(s))
                end
                file[o.yname][idcs..., o.saved+1] = yfun(ts)
                s = collect(size(file[o.tname]))
                if s[end] < o.saved+1
                    s[end] += 1
                    HDF5.set_dims!(file[o.tname], Tuple(s))
                end
                file[o.tname][o.saved+1] = ts
                o.saved += 1
                save, ts = o.save_cond(y, t, dt, o.saved)
            end
            append_stats!(file["stats"], o.stats_tmp)
            o.stats_tmp = Vector{Dict{String, Any}}()
        end
    end

end

function append_stats!(parent, a::Array{Dict{String,Any},1})
    N = length(a)
    names = HDF5.names(parent)
    for (k, v) in pairs(a[1])
        if ~(k in names)
            create_dataset(parent, k, v)
        end
        s = collect(size(parent[k]))
        curN = s[end]
        if ~(k in names)
            curN -= 1 # new dataset - overwrite initial value
        end
        s[end] += N
        if ~(k in names)
            s[end] -= 1 # new dataset - overwrite initial value
        end
        HDF5.set_dims!(parent[k], Tuple(s))
        for ii = 1:N
            parent[k][fill(:, ndims(a[ii][k]))..., curN+ii] = a[ii][k]
        end
    end
end

function create_dataset(parent, name, x::Number)
    @hlock HDF5.d_create(parent, name, HDF5.datatype(typeof(x)), ((1,), (-1,)),
                  "chunk", (1,))
end

function create_dataset(parent, name, x::AbstractArray)
    dims = (size(x)..., 1)
    maxdims = (size(x)..., -1)
    @hlock HDF5.d_create(parent, name, HDF5.datatype(eltype(x)), (dims, maxdims),
                  "chunk", dims)
end

"Calling the output on a dictionary writes the items to the file"
function (o::HDF5Output)(d::AbstractDict; force=false, meta=false, group=nothing)
    @hlock HDF5.h5open(o.fpath, "r+") do file
        parent = meta ? file["meta"] : file
        for (k, v) in pairs(d)
            if HDF5.exists(parent, k)
                if force
                    Logging.@warn("Dataset $k already present in file $(o.fpath)"*
                                  " and will be overwritten")
                    HDF5.o_delete(parent, k)
                else
                    error("File $(o.fpath) already has dataset $(k)")
                end
            end
            isa(v, BitArray) && (v = Array{Bool, 1}(v))
            if !isnothing(group)
                if !HDF5.exists(parent, group)
                    HDF5.g_create(parent, group)
                end
                parent[group][k] = v
            else
                parent[k] = v
            end
        end
    end
end

"Calling the output on a key, value pair writes the value to the file"
function (o::HDF5Output)(key::AbstractString, val; force=false, meta=false, group=nothing)
    @hlock HDF5.h5open(o.fpath, "r+") do file
        parent = meta ? file["meta"] : file
        if HDF5.exists(parent, key)
            if force
                Logging.@warn("Dataset $key already present in file $(o.fpath)"*
                                " and will be overwritten")
                HDF5.o_delete(parent, key)
            else
                error("File $(o.fpath) already has dataset $(key)")
            end
        end
        isa(val, BitArray) && (v = Array{Bool, 1}(val))
        if !isnothing(group)
            if !HDF5.exists(parent, group)
                HDF5.g_create(parent, group)
            end
            parent[group][key] = val
        else
            parent[key] = val
        end
    end
end

"Condition callable that distributes save points evenly on a grid"
struct GridCondition
    grid::Vector{Float64}
    saveN::Integer
end

function GridCondition(tmin, tmax, saveN)
    GridCondition(range(tmin, stop=tmax, length=saveN), saveN)
end

function (cond::GridCondition)(y, t, dt, saved)
    save = (saved < cond.saveN) && cond.grid[saved+1] <= t
    return save, save ? cond.grid[saved+1] : 0
end

"Condition which saves every native point of the propagation"
function always(y, t, dt, saved)
    return true, t
end

"Condition which saves every nth native point"
function every_nth(n)
    i = 0
    cond = let i = i, n = n
        function condition(y, t, dt, saved)
            save = i % n == 0
            i += 1
            return save, t
        end
    end
    return cond
end

"""Making initial array dimensions.
For a GridCondition, we know in advance how many points there will be.
"""
function init_dims(ydims, save_cond::GridCondition)
    return (ydims..., save_cond.saveN)
end

"For other conditions, we do not know in advance."
function init_dims(ydims, save_cond)
    return (ydims..., 1)
end

function nostats(args...)
    return Dict{String, Any}()
end

macro ScanHDF5Output(args...)
    code = ""
    try
        script = string(__source__.file)
        isdir(Utils.cachedir()) || mkpath(Utils.cachedir())
        code = open(script, "r") do file
            read(file, String)
        end
    catch
    end
    for arg in args
        if isa(arg, Expr) && arg.head == :(=)
            arg.head = :kw
        end
    end
    fname = quote
        $(esc(:__SCAN__)).name*"_"*@sprintf("%05d", $(esc(:__SCANIDX__)))*".h5"
    end
    exp = Expr(:call, HDF5Output, fname)
    for arg in args
        push!(exp.args, esc(arg))
    end
    push!(exp.args, Expr(:kw, :script, code))
    quote 
        begin
            out = $exp
            out("scanidx", $(esc(:__SCANIDX__)),  meta=true)
            vars = Dict{String, Any}()
            for var in keys($(esc(:__SCAN__)).vars)
                val = Scans.getval($(esc(:__SCAN__)), var, $(esc(:__SCANIDX__)))
                vars[string(var)] = val
            end
            out(vars, meta=true, group="scanvars")
            out
        end
    end
end

# Auto-generate @MemoryOutput and @HDF5Output macros
for op in (:MemoryOutput, :HDF5Output)
    eval(
        quote
            macro $op(args...)
                script_code = ""
                try
                    script = string(__source__.file)
                    isdir(Utils.cachedir()) || mkpath(Utils.cachedir())
                    code = open(script, "r") do file
                        read(file, String)
                    end
                    script_code = script*"\n"*code
                catch
                end
                for arg in args
                    if isa(arg, Expr) && arg.head == :(=)
                        arg.head = :kw
                    end
                end
                exp = Expr(:call, $op)
                for arg in args
                    push!(exp.args, esc(arg))
                end
                push!(exp.args, Expr(:kw, :script, script_code))
                exp
            end
        end
    )
end
            
end
