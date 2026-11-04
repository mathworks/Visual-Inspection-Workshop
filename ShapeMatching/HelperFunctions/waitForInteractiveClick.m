function result = waitForInteractiveClick(hFig,opts)
%waitForInteractiveClick Wait for explicit placement confirmation.
%   RESULT = waitForInteractiveClick(HFIG) blocks until the user
%   confirms placement in HFIG using a Done button. An optional Cancel
%   button, timeout, or closing the figure also resume the wait.
%
%   RESULT is a struct with fields:
%     Reason        - "done" | "cancel" | "figureclosed" | "timeout"
%     HitObject     - current object handle when available, or []
%     HitClass      - class name of HitObject
%     SelectionType - "done" | "cancel" | ""
%     Figure        - source figure handle

arguments
    hFig (1,1) matlab.ui.Figure
    opts.Timeout (1,1) double {mustBePositive} = inf
    opts.AcceptClasses (1,:) string = [ ...
        "images.ui.graphics.roi.Caliper" ...
        "images.ui.graphics.roi.Angle"]
    opts.TargetFilterFcn function_handle = function_handle.empty()
    opts.ShowCancelButton (1,1) logical = true
end

result = struct( ...
    "Reason","", ...
    "HitObject",[], ...
    "HitClass","", ...
    "SelectionType","", ...
    "Figure",hFig);

listeners = event.listener.empty(0,1);
timeoutTimer = [];
isFinished = false;

listeners(end+1) = addlistener(hFig,"ObjectBeingDestroyed",@handleFigureDestroyed);

if isfinite(opts.Timeout)
    timeoutTimer = timer( ...
        "ExecutionMode","singleShot", ...
        "StartDelay",opts.Timeout, ...
        "TimerFcn",@(~,~) handleTimeout());
    start(timeoutTimer);
end

buttonHandles = createActionButtons(hFig,opts.ShowCancelButton);

cleanupObj = onCleanup(@() cleanupResources(timeoutTimer,listeners,buttonHandles));
uiwait(hFig);

    function handleFigureDestroyed(~,~)
        if isFinished
            return;
        end

        isFinished = true;
        if result.Reason == ""
            result.Reason = "figureclosed";
        end
    end

    function handleTimeout()
        if isFinished
            return;
        end

        result.Reason = "timeout";
        finishWait(hFig);
    end

    function buttonList = createActionButtons(parentFig,showCancelButton)
        buttonList = gobjects(0,1);

        buttonList(end+1,1) = uicontrol(parentFig, ...
            "Style","pushbutton", ...
            "String","Done", ...
            "Units","normalized", ...
            "Position",[0.78 0.94 0.10 0.05], ...
            "FontWeight","bold", ...
            "Callback",@handleDoneButtonPress);

        if showCancelButton
            buttonList(end+1,1) = uicontrol(parentFig, ...
                "Style","pushbutton", ...
                "String","Cancel", ...
                "Units","normalized", ...
                "Position",[0.89 0.94 0.10 0.05], ...
                "Callback",@handleCancelButtonPress);
        end
    end

    function handleDoneButtonPress(~,~)
        if isFinished
            return;
        end

        [rawHit,rawHitClass] = resolveCurrentHit();
        [acceptedHit,acceptedClass] = resolveAcceptedHit(rawHit);

        result.Reason = "done";
        if ~isempty(acceptedHit)
            result.HitObject = acceptedHit;
            result.HitClass = acceptedClass;
        else
            result.HitObject = rawHit;
            result.HitClass = rawHitClass;
        end
        result.SelectionType = "done";
        finishWait(hFig);
    end

    function handleCancelButtonPress(~,~)
        if isFinished
            return;
        end

        result.Reason = "cancel";
        result.SelectionType = "cancel";
        finishWait(hFig);
    end

    function [rawHit,rawHitClass] = resolveCurrentHit()
        try
            rawHit = hFig.CurrentObject;
        catch
            rawHit = [];
        end

        [rawHit,rawHitClass] = resolveRawHit(rawHit);
    end

    function [acceptedHit,acceptedClass] = resolveAcceptedHit(rawHit)
        acceptedHit = [];
        acceptedClass = "";
        currentHit = rawHit;

        while ~isempty(currentHit)
            try
                currentClass = string(class(currentHit));
            catch
                return;
            end

            if any(currentClass == opts.AcceptClasses)
                acceptedHit = currentHit;
                acceptedClass = currentClass;

                if ~isempty(opts.TargetFilterFcn)
                    acceptedHit = opts.TargetFilterFcn(acceptedHit,rawHit,hFig);
                    if isempty(acceptedHit)
                        acceptedClass = "";
                    else
                        acceptedClass = string(class(acceptedHit));
                    end
                end
                return;
            end

            if ~isprop(currentHit,"Parent")
                return;
            end

            try
                currentHit = currentHit.Parent;
            catch
                return;
            end
        end
    end

    function [resolvedHit,resolvedClass] = resolveRawHit(rawHit)
        resolvedHit = [];
        resolvedClass = "";

        if isempty(rawHit)
            return;
        end

        try
            resolvedHit = rawHit;
            resolvedClass = string(class(rawHit));
        catch
            resolvedHit = [];
            resolvedClass = "";
        end
    end

    function finishWait(src)
        if isFinished
            return;
        end

        isFinished = true;
        if isvalid(src)
            uiresume(src);
        end
    end

    function cleanupResources(localTimer,localListeners,localButtons)
        if ~isempty(localTimer) && isa(localTimer,"timer") && isvalid(localTimer)
            stop(localTimer);
            delete(localTimer);
        end

        if ~isempty(localButtons)
            for buttonIdx = 1:numel(localButtons)
                if isgraphics(localButtons(buttonIdx))
                    delete(localButtons(buttonIdx));
                end
            end
        end

        if ~isempty(localListeners)
            for listenerIdx = 1:numel(localListeners)
                if isvalid(localListeners(listenerIdx))
                    delete(localListeners(listenerIdx));
                end
            end
        end
    end
end
