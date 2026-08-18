import { standardSchemaResolver } from "@hookform/resolvers/standard-schema";
import {
  createFileRoute,
  Link,
  useRouter,
  useSearch,
} from "@tanstack/react-router";
import { REGEXP_ONLY_DIGITS } from "input-otp";
import { ArrowLeft, RefreshCcw } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { z } from "zod/v4";
import PageTitle from "@/components/page-title";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
} from "@/components/ui/input-otp";
import { authClient } from "@/lib/auth-client";
import { toast } from "@/lib/toast";
import {
  getAuthApiBaseUrl,
  isTwoFactorRequiredMessage,
} from "@/lib/two-factor";
import { AuthLayout } from "../../components/auth/layout";

export const Route = createFileRoute("/auth/verify-otp")({
  component: VerifyOtp,
  validateSearch: (search: Record<string, unknown>) => ({
    email: search.email as string,
    invitationId: search.invitationId as string | undefined,
    redirect: search.redirect as string | undefined,
  }),
});

function VerifyOtp() {
  const { t } = useTranslation();
  const { history } = useRouter();
  const { email, invitationId, redirect } = useSearch({
    from: "/auth/verify-otp",
  });
  const [isPending, setIsPending] = useState(false);
  // Gesetzt, wenn der Server einen Email-OTP-Sign-in für ein Konto mit
  // aktiviertem 2FA verweigert. Statt einer flüchtigen Meldung bleibt dann
  // eine verständliche, handlungsleitende Abweisung mit Passwort-Anmeldelink
  // stehen (der better-auth-Client hängt bei dieser 401 — siehe lib/two-factor).
  const [twoFactorRequired, setTwoFactorRequired] = useState(false);

  const verifyOtpSchema = useMemo(
    () =>
      z.object({
        otp: z.string().length(6, t("auth:verifyOtp.validation.codeLength")),
      }),
    [t],
  );

  type VerifyOtpFormValues = z.infer<typeof verifyOtpSchema>;

  const form = useForm<VerifyOtpFormValues>({
    resolver: standardSchemaResolver(verifyOtpSchema),
    defaultValues: { otp: "" },
  });

  const safeRedirect = useMemo(() => {
    if (redirect?.startsWith("/") && !redirect.includes("//")) {
      return redirect;
    }
    return undefined;
  }, [redirect]);

  const signInPath = useMemo(() => {
    if (!redirect) {
      return "/auth/sign-in";
    }

    return `/auth/sign-in?redirect=${encodeURIComponent(redirect)}`;
  }, [redirect]);

  const onSubmit = useCallback(
    async (data: VerifyOtpFormValues) => {
      setIsPending(true);
      setTwoFactorRequired(false);
      try {
        // A first-time OTP sign-in creates the account, so instances with
        // DISABLE_REGISTRATION=true reject it unless the request carries the
        // invitation the visitor arrived with.
        //
        // Wir rufen den Endpunkt direkt per `fetch` auf statt über
        // authClient.signIn.emailOtp: dessen Promise hängt bei der 401-Antwort,
        // mit der der Server den Email-OTP-Weg für 2FA-Konten sperrt (siehe
        // lib/two-factor). Das würde die Seite endlos auf „Verifying...“
        // festhalten. Ein eigener fetch löst immer auf und lässt uns die
        // 2FA-Abweisung verständlich anzeigen.
        const response = await fetch(
          `${getAuthApiBaseUrl()}/api/auth/sign-in/email-otp`,
          {
            method: "POST",
            credentials: "include",
            headers: {
              "content-type": "application/json",
              ...(invitationId ? { "x-invitation-id": invitationId } : {}),
            },
            body: JSON.stringify({ email, otp: data.otp }),
          },
        );
        const result = (await response.json().catch(() => ({}))) as {
          message?: string;
          code?: string;
        };

        if (!response.ok) {
          if (isTwoFactorRequiredMessage(result.message)) {
            setTwoFactorRequired(true);
          } else {
            toast.error(
              result.message || t("auth:verifyOtp.toast.invalidCode"),
            );
          }
          return;
        }

        toast.success(t("auth:verifyOtp.toast.signedInSuccess"));
        if (safeRedirect) {
          history.push(safeRedirect);
        } else if (invitationId) {
          history.push(`/invitation/accept/${invitationId}`);
        } else {
          history.push("/dashboard");
        }
      } catch (error) {
        toast.error(
          error instanceof Error
            ? error.message
            : t("auth:verifyOtp.toast.verifyFailed"),
        );
      } finally {
        setIsPending(false);
      }
    },
    [email, invitationId, history, safeRedirect, t],
  );

  useEffect(() => {
    const subscription = form.watch((value, { name }) => {
      if (name === "otp" && value.otp?.length === 6 && !isPending) {
        form.handleSubmit(onSubmit)();
      }
    });
    return () => subscription.unsubscribe();
  }, [form, isPending, onSubmit]);

  const handleResendOtp = async () => {
    setIsPending(true);
    try {
      const result = await authClient.emailOtp.sendVerificationOtp({
        email,
        type: "sign-in",
      });

      if (result.error) {
        toast.error(
          result.error.message || t("auth:verifyOtp.toast.resendFailed"),
        );
        return;
      }

      toast.success(t("auth:verifyOtp.toast.resendSuccess"));
      form.reset();
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : t("auth:verifyOtp.toast.resendFailed"),
      );
    } finally {
      setIsPending(false);
    }
  };

  return (
    <>
      <PageTitle title={t("auth:verifyOtp.pageTitle")} />
      <AuthLayout
        title={t("auth:verifyOtp.title")}
        subtitle={t("auth:verifyOtp.subtitle")}
      >
        <div className="space-y-4">
          {twoFactorRequired && (
            <Alert variant="error">
              <AlertTitle>
                {t("auth:verifyOtp.twoFactorRequired.title")}
              </AlertTitle>
              <AlertDescription>
                <span>{t("auth:verifyOtp.twoFactorRequired.description")}</span>
                <Button
                  variant="outline"
                  render={<Link to={signInPath} />}
                  className="w-full"
                >
                  {t("auth:verifyOtp.twoFactorRequired.signInWithPassword")}
                </Button>
              </AlertDescription>
            </Alert>
          )}

          <Alert>
            <AlertDescription className="text-xs">
              {t("auth:verifyOtp.codeSentTo", { email })}
            </AlertDescription>
          </Alert>

          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="otp"
                render={({ field, fieldState }) => (
                  <FormItem>
                    <FormLabel className="text-sm font-medium sr-only">
                      {t("auth:verifyOtp.verificationCodeLabel")}
                    </FormLabel>
                    <FormControl>
                      <InputOTP
                        maxLength={6}
                        value={field.value}
                        onChange={field.onChange}
                        onBlur={field.onBlur}
                        pattern={REGEXP_ONLY_DIGITS}
                        autoComplete="one-time-code"
                        inputMode="numeric"
                        name="one-time-code"
                      >
                        <InputOTPGroup className="grid w-full grid-cols-6 gap-1.5">
                          <InputOTPSlot className="h-11 w-full" index={0} />
                          <InputOTPSlot className="h-11 w-full" index={1} />
                          <InputOTPSlot className="h-11 w-full" index={2} />
                          <InputOTPSlot className="h-11 w-full" index={3} />
                          <InputOTPSlot className="h-11 w-full" index={4} />
                          <InputOTPSlot className="h-11 w-full" index={5} />
                        </InputOTPGroup>
                      </InputOTP>
                    </FormControl>
                    <FormMessage>{fieldState.error?.message}</FormMessage>
                  </FormItem>
                )}
              />

              <Button type="submit" disabled={isPending} className="w-full">
                {isPending
                  ? t("auth:verifyOtp.verifying")
                  : t("auth:verifyOtp.verifyAndSignIn")}
              </Button>

              <div className="grid grid-cols-2 gap-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => history.push(signInPath)}
                  className="w-full"
                >
                  <ArrowLeft className="size-4" />
                  {t("auth:verifyOtp.changeEmail")}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={handleResendOtp}
                  disabled={isPending}
                  className="w-full"
                >
                  <RefreshCcw className="size-4" />
                  {t("auth:verifyOtp.resend")}
                </Button>
              </div>
            </form>
          </Form>
        </div>
      </AuthLayout>
    </>
  );
}
