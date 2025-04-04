
# provides functionality for exception handling
#module ExceptionHandling

    #export signal, error, handling, to_escape, with_restart, invoke_restart, available_restart

    struct EscapeException <: Exception
        id
        value
    end

    # Define global stacks for restarts and handlers
    const RESTART_STACK = Vector{Vector{Pair{Symbol, Function}}}()
    const HANDLER_STACK = Vector{Vector{Pair{Type{<:Exception}, Function}}}()



    # Execute most recent handler
    function signal(e::Exception, mustBeHandled::Bool = false)
        for frame in reverse(HANDLER_STACK)  # Reverse order to obtain latest stackframe
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



    # Add handler to handlerstack 
    function handling(f::Function, handlers...) 
        push!(HANDLER_STACK, collect(handlers))  # Push stackframe onto stack
        try
            return f()
        finally
            pop!(HANDLER_STACK)  # Restore previous state by popping the stackframe
        end
    end



    #Take an anonymous function which has the named exit as an arugment with a return value
    function to_escape(f::Function)
        id = gensym() 
        try
            return f(x -> throw(EscapeException(id, x)))  
        catch e
            if e isa EscapeException && e.id == id 
                return e.value  # Return the escaped value
            else
                rethrow()
            end
        end
    end



    # Provide restarts with defined exit points
    function with_restart(f::Function, restarts...)
    to_escape() do exit
            # map callback to anonymous function that calls exit with callback(args...) to create non-local transer of control
            new_restarts = map(((name, callback), ) -> name => (args...) -> exit(callback(args...)), restarts) 
            push!(RESTART_STACK, collect(new_restarts))
            try
                return f()
            finally
                pop!(RESTART_STACK)  # Remove last stackframe
            end
        end
    end

    function available_restart(name::Symbol)
        for frame in reverse(RESTART_STACK)
            for (restart_name, _) in frame
                if name  === restart_name
                    return true
                end
            end
        end

        return false
    end

    # If restart available, return callback with arguments
    function invoke_restart(name::Symbol, args...)
        if available_restart(name)
            for frame in Iterators.reverse(RESTART_STACK)
                for (restart_name, callback) in frame
                    if name  === restart_name
                        callback(args...)
                    end
                end
            end
        else
            error("No callback found!")
        end
    end

#end

