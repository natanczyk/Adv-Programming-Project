# Custom exception
struct DivisionByZero <: Exception end
struct EscapeException <: Exception
    value
end

# Define global stacks for restarts and handlers
const RESTART_STACK = Dict{Symbol, Function}()
const HANDLER_STACK = Vector{Vector{Pair{Type{DivisionByZero}, Function}}}()

# Execute most recent handler
function signal(e::Exception, mustBeHandled::Bool = false)
    for frame in reverse(HANDLER_STACK)  # Reverse to get most recent
        for (exc_type, handler) in frame
            if e isa exc_type
                handler(e)
                break  # break after handling
            end
        end
    end
    if mustBeHandled
        throw(e)
    end
end

# Signal an error that must be handled
function error(e::Exception)
    signal(e, true)
end

# Store handler globally
function handling(f::Function, handlers...)
    #stackframe = [(exc_type => handler) for (exc_type, handler) in handlers]  >> not needed right?  
    push!(HANDLER_STACK, collect(handlers))  # Push stackframe onto stack
    try
        return f()
    finally
        pop!(HANDLER_STACK)  # Restore previous state by popping the stackframe
    end
end

# define restarts
# chatGPT Code!
#=
function with_restart(f::Function, handlers...)
    
    local previous_restarts = copy(RESTART_STACK)
    try
        for (name, restart_func) in restarts
            RESTART_STACK[name] = restart_func
        end
        return f()
    finally
        empty!(RESTART_STACK)
        merge!(RESTART_STACK, previous_restarts)
    end
end
=#
function with_restart(fun::Function, handlers...)
    to_escape() do exit  # Establish an escape point
        existing_handlers = Dict(RESTART_STACK)  # Backup current restarts
        for (name, callback) in handlers
            RESTART_STACK[name] = args -> exit(callback(args...))  
        end
        try
            return fun()
        finally
            # Restore previous handlers after execution
            empty!(RESTART_STACK)
            merge!(RESTART_STACK, existing_handlers)
        end
    end
end


# Check if a restart is available
# chatGPT Code!
function available_restart(name::Symbol)
    return haskey(RESTART_STACK, name)
end

#=
# Invoke a restart
# chatGPT Code!
function invoke_restart(name::Symbol, args...)
    if available_restart(name)
        return RESTART_STACK[name](args...)
    else
        error("Restart $name not available")
    end
end
=#

function invoke_restart(name::Symbol, args...)
    if available_restart(name)
        to_escape() do exit  # Create an escape point
            exit(RESTART_STACK[name](args...))  # Call the restart and exit
        end
    else
        error("Restart $name not available")
    end
end

function to_escape(f::Function)
    try
        return f(x -> throw(EscapeException(x)))  # `x` is the exit function
    catch e
        if e isa EscapeException
            return e.value  # Return the escaped value
        else
            rethrow()
        end
    end
end



#                            Test
#--------------------------------------------------------------------------------------------
#=
reciprocal(x) =
    x == 0 ?
        error(DivisionByZero()) :
        1/x


handling(DivisionByZero => (c)->println("I saw it too")) do 
    handling(DivisionByZero => (c)->println("I saw a division by zero")) do
        reciprocal(0)
    end
end

handling(DivisionByZero => (c)->invoke_restart(:return_zero)) do
    reciprocal(0)
end
=#

reciprocal2(value) =
    with_restart(:return_zero => ()->0,
            :return_value => identity,
            :retry_using => reciprocal) do
        value == 0 ?
            error(DivisionByZero()) :
            1/value
    end

handling(DivisionByZero => (c)->invoke_restart(:return_zero)) do
    reciprocal2(0)
end


to_escape() do exit
    handling(DivisionByZero =>
    (c)->(println("I saw it too"); exit("Done"))) do
        handling(DivisionByZero =>
        (c)->println("I saw a division by zero")) do
        reciprocal(0)
        end
    end
end

