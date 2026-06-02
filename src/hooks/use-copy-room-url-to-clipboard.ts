import { useCallback, useMemo } from "react";
import { toast } from "@/lib/toast";
import { copyTextToClipboard } from "@/utils/copy-text-to-clipboard";
import { buildPublicRoomUrl } from "@/utils/public-url";

interface UseCopyRoomUrlReturn {
  copyRoomUrlToClipboard: (roomId: string) => Promise<void>;
}

export function useCopyRoomUrlToClipboard(): UseCopyRoomUrlReturn {
  const copyRoomUrlToClipboard = useCallback(async (roomId: string) => {
    const isCopySuccess = await copyTextToClipboard(buildPublicRoomUrl(roomId));

    if (isCopySuccess) {
      toast.success("Invite link copied to clipboard");
    } else {
      toast.error(
        "When copying an invite link something went wrong. But don't be discouraged, just copy it yourself from the browser."
      );
    }
  }, []);

  return useMemo(() => ({ copyRoomUrlToClipboard }), [copyRoomUrlToClipboard]);
}
