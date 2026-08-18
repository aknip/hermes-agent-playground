import { createFileRoute, useRouter } from "@tanstack/react-router";
import { REGEXP_ONLY_DIGITS } from "input-otp";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { z } from "zod/v4";
import PageTitle from "@/components/page-title";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
} from "@/components/ui/input-otp";
import { authClient } from "@/lib/auth-client";
import { toast } from "@/lib/toast";
import { AuthLayout } from "../../components/auth/layout";

export const Route = createFileRoute("/auth/two-factor")({
  component: TwoFactor,
});

function TwoFactor() {
  const { t } = useTranslation();
  const { history } = useRouter();
  const [isPending, setIsPending] = useState(false);
  const [usingBackupCode, setUsingBackupCode] = useState(false);

  const twoFactorSchema = useMemo(
    () =>
      z.object({
        code: z.string().min(6, t("auth:twoFactor.invalidCode")),
      }),
    [t],
  );

  type TwoFactorFormValues = z.infer<typeof twoFactorSchema>;

  const form = useForm<TwoFactorFormValues>({
    resolver: undefined,
    defaultValues: { code: "" },
  });

  const onSubmit = useCallback(
    async (data: TwoFactorFormValues) => {
      setIsPending(true);
      try {
        const result = usingBackupCode
          ? await authClient.twoFactor.verifyBackupCode({ code: data.code })
          : await authClient.twoFactor.verifyTotp({ code: data.code });

        if (result.error) {
          toast.error(result.error.message || t("auth:twoFactor.invalidCode"));
          return;
        }
        history.replace("/dashboard");
      } catch (error) {
        toast.error(
          error instanceof Error
            ? error.message
            : t("auth:twoFactor.verifyFailed"),
        );
      } finally {
        setIsPending(false);
      }
    },
    [history, t, usingBackupCode],
  );

  useEffect(() => {
    const subscription = form.watch((value, { name }) => {
      if (name === "code" && value.code?.length === 6 && !isPending) {
        form.handleSubmit(onSubmit)();
      }
    });
    return () => subscription.unsubscribe();
  }, [form, isPending, onSubmit]);

  return (
    <>
      <PageTitle title={t("auth:twoFactor.pageTitle")} />
      <AuthLayout
        title={t("auth:twoFactor.title")}
        subtitle={t("auth:twoFactor.subtitle")}
      >
        <div className="space-y-4">
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="code"
                render={({ field, fieldState }) => (
                  <FormItem>
                    {!usingBackupCode ? (
                      <>
                        <FormLabel className="text-sm font-medium sr-only">
                          {t("auth:twoFactor.codeLabel")}
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
                            name="two-factor-code"
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
                      </>
                    ) : (
                      <>
                        <FormLabel className="text-sm font-medium">
                          {t("auth:twoFactor.backupCodeLabel")}
                        </FormLabel>
                        <FormControl>
                          <Input
                            autoComplete="off"
                            inputMode="text"
                            autoCapitalize="none"
                            spellCheck={false}
                            placeholder={t("auth:twoFactor.backupCodeLabel")}
                            {...field}
                          />
                        </FormControl>
                      </>
                    )}
                    <FormMessage>{fieldState.error?.message}</FormMessage>
                  </FormItem>
                )}
              />

              <Button type="submit" disabled={isPending} className="w-full">
                {isPending
                  ? t("auth:twoFactor.verifying")
                  : t("auth:twoFactor.verifyButton")}
              </Button>
            </form>
          </Form>

          <Button
            type="button"
            variant="ghost"
            className="w-full"
            onClick={() => {
              setUsingBackupCode((value) => !value);
              form.reset();
            }}
          >
            {usingBackupCode
              ? t("auth:twoFactor.useAppCode")
              : t("auth:twoFactor.backupCodeHint")}
          </Button>
        </div>
      </AuthLayout>
    </>
  );
}
