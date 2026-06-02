"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { useMutation } from "convex/react";
import { Loader2 } from "lucide-react";

import { api } from "@/convex/_generated/api";
import { authClient } from "@/lib/auth-client";
import { generateGuestName } from "@/lib/guest-names";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export function SigninForm({ className, ...props }: React.ComponentProps<"div">) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const ensureGlobalUser = useMutation(api.users.ensureGlobalUser);

  const rawFrom = searchParams.get("from") || "/";
  const from =
    rawFrom.startsWith("/") && !rawFrom.startsWith("//") ? rawFrom : "/";

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleGuestSignIn = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const result = await authClient.signIn.anonymous();
      if (result.error) {
        setError(
          result.error.message ||
            `Failed to continue as guest (${result.error.statusText})`
        );
        setIsLoading(false);
        return;
      }

      const newAuthUserId = result.data?.user?.id;
      if (newAuthUserId) {
        await ensureGlobalUser({
          authUserId: newAuthUserId,
          name: generateGuestName(),
        });
      }

      router.push(from);
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Failed to continue as guest";
      setError(message);
      setIsLoading(false);
    }
  };

  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-xl">Continue as guest</CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="mb-4 rounded-md bg-destructive/15 p-3 text-sm text-destructive">
              {error}
            </div>
          )}
          <Button
            className="w-full"
            onClick={handleGuestSignIn}
            disabled={isLoading}
          >
            {isLoading ? <Loader2 className="mr-2 size-4 animate-spin" /> : null}
            Continue as guest
          </Button>
        </CardContent>
      </Card>
      <div className="px-6 text-center text-balance text-muted-foreground text-sm">
        By clicking continue, you agree to our{" "}
        <Link
          href="/terms"
          className="underline underline-offset-4 hover:text-primary"
        >
          Terms of Service
        </Link>{" "}
        and{" "}
        <Link
          href="/privacy"
          className="underline underline-offset-4 hover:text-primary"
        >
          Privacy Policy
        </Link>
        .
      </div>
    </div>
  );
}
