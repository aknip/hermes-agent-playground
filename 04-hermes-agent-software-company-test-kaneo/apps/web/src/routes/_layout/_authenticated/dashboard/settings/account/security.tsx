import { standardSchemaResolver } from "@hookform/resolvers/standard-schema";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { z } from "zod/v4";
import PageTitle from "@/components/page-title";
import useAuth from "@/components/providers/auth-provider/hooks/use-auth";
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
import { Separator } from "@/components/ui/separator";
import { authClient } from "@/lib/auth-client";
import { toast } from "@/lib/toast";

export const Route = createFileRoute(
  "/_layout/_authenticated/dashboard/settings/account/security",
)({
  component: RouteComponent,
});

type EnableFormValues = {
  password: string;
};

type VerifyFormValues = {
  code: string;
};

function RouteComponent() {
  const { t } = useTranslation();
  const { user, refetchUser } = useAuth();
  const enabled = Boolean(user?.twoFactorEnabled);
  const [isPending, setIsPending] = useState(false);
  const [isEnabling, setIsEnabling] = useState(false);
  const [totpUri, setTotpUri] = useState<string | null>(null);
  const [backupCodes, setBackupCodes] = useState<string[] | null>(null);

  const enableSchema = z.object({
    password: z.string().min(1),
  });
  const enableForm = useForm<EnableFormValues>({
    resolver: standardSchemaResolver(enableSchema),
    defaultValues: { password: "" },
  });

  const verifySchema = z.object({
    code: z.string().length(6),
  });
  const verifyForm = useForm<VerifyFormValues>({
    resolver: standardSchemaResolver(verifySchema),
    defaultValues: { code: "" },
  });

  const disableSchema = z.object({
    password: z.string().min(1),
  });
  const disableForm = useForm<{ password: string }>({
    resolver: standardSchemaResolver(disableSchema),
    defaultValues: { password: "" },
  });

  const handleEnable = async ({ password }: EnableFormValues) => {
    setIsPending(true);
    try {
      const result = await authClient.twoFactor.enable({ password });
      if (result.error) {
        toast.error(
          result.error.message || t("settings:securityPage.enableError"),
        );
        return;
      }
      if (result.data?.totpURI) {
        setTotpUri(result.data.totpURI);
        setBackupCodes(result.data.backupCodes ?? []);
        setIsEnabling(true);
        enableForm.reset();
      }
    } finally {
      setIsPending(false);
    }
  };

  const handleVerify = async ({ code }: VerifyFormValues) => {
    setIsPending(true);
    try {
      const result = await authClient.twoFactor.verifyTotp({ code });
      if (result.error) {
        toast.error(
          result.error.message || t("settings:securityPage.invalidCode"),
        );
        return;
      }
      setTotpUri(null);
      setBackupCodes(null);
      setIsEnabling(false);
      await refetchUser();
      toast.success(t("settings:securityPage.enableSuccess"));
    } finally {
      setIsPending(false);
    }
  };

  const handleDisable = async ({ password }: { password: string }) => {
    setIsPending(true);
    try {
      const result = await authClient.twoFactor.disable({ password });
      if (result.error) {
        toast.error(
          result.error.message || t("settings:securityPage.disableError"),
        );
        return;
      }
      await refetchUser();
      disableForm.reset();
      toast.success(t("settings:securityPage.disableSuccess"));
    } finally {
      setIsPending(false);
    }
  };

  return (
    <>
      <PageTitle title={t("settings:securityPage.pageTitle")} />
      <div className="max-w-4xl mx-auto space-y-8">
        <div className="space-y-2">
          <h1 className="text-2xl font-semibold">
            {t("settings:securityPage.title")}
          </h1>
          <p className="text-muted-foreground">
            {t("settings:securityPage.subtitle")}
          </p>
        </div>

        <div className="space-y-6">
          <div className="space-y-4 border border-border rounded-md p-4 bg-sidebar">
            <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between sm:gap-4">
              <div className="space-y-0.5">
                <p className="text-sm font-medium">
                  {enabled
                    ? t("settings:securityPage.statusEnabled")
                    : t("settings:securityPage.statusDisabled")}
                </p>
                <p className="text-xs text-muted-foreground">
                  {enabled
                    ? t("settings:securityPage.disableDescription")
                    : t("settings:securityPage.enableDescription")}
                </p>
              </div>

              {enabled ? (
                <Form {...disableForm}>
                  <form
                    onSubmit={disableForm.handleSubmit(handleDisable)}
                    className="flex flex-col items-end gap-2 sm:flex-row"
                  >
                    <FormField
                      control={disableForm.control}
                      name="password"
                      render={({ field, fieldState }) => (
                        <FormItem>
                          <FormControl>
                            <Input
                              type="password"
                              placeholder={t(
                                "settings:securityPage.currentPasswordPlaceholder",
                              )}
                              autoComplete="current-password"
                              className="w-full sm:w-56"
                              {...field}
                            />
                          </FormControl>
                          <FormMessage>{fieldState.error?.message}</FormMessage>
                        </FormItem>
                      )}
                    />
                    <Button
                      type="submit"
                      variant="outline"
                      size="sm"
                      disabled={isPending}
                    >
                      {t("settings:securityPage.disable")}
                    </Button>
                  </form>
                </Form>
              ) : (
                <Form {...enableForm}>
                  <form
                    onSubmit={enableForm.handleSubmit(handleEnable)}
                    className="flex flex-col items-end gap-2 sm:flex-row"
                  >
                    <FormField
                      control={enableForm.control}
                      name="password"
                      render={({ field, fieldState }) => (
                        <FormItem>
                          <FormControl>
                            <Input
                              type="password"
                              placeholder={t(
                                "settings:securityPage.currentPasswordPlaceholder",
                              )}
                              autoComplete="current-password"
                              className="w-full sm:w-56"
                              {...field}
                            />
                          </FormControl>
                          <FormMessage>{fieldState.error?.message}</FormMessage>
                        </FormItem>
                      )}
                    />
                    <Button
                      type="submit"
                      variant="default"
                      size="sm"
                      disabled={isPending}
                    >
                      {t("settings:securityPage.enable")}
                    </Button>
                  </form>
                </Form>
              )}
            </div>

            {isEnabling && totpUri ? (
              <>
                <Separator />
                <div className="space-y-4">
                  <div className="space-y-0.5">
                    <p className="text-sm font-medium">
                      {t("settings:securityPage.totpTitle")}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {t("settings:securityPage.totpSubtitle")}
                    </p>
                  </div>

                  <Input
                    readOnly
                    value={totpUri}
                    aria-label={t("settings:securityPage.secretLabel")}
                    className="font-mono text-xs"
                  />

                  <div className="space-y-0.5">
                    <p className="text-sm font-medium">
                      {t("settings:securityPage.backupCodesTitle")}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {t("settings:securityPage.backupCodesOneTime")}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {backupCodes?.map((code) => (
                      <code
                        key={code}
                        className="rounded border border-border bg-muted px-2 py-1 font-mono text-xs"
                      >
                        {code}
                      </code>
                    ))}
                  </div>

                  <Form {...verifyForm}>
                    <form
                      onSubmit={verifyForm.handleSubmit(handleVerify)}
                      className="space-y-3"
                    >
                      <FormField
                        control={verifyForm.control}
                        name="code"
                        render={({ field, fieldState }) => (
                          <FormItem>
                            <FormLabel className="text-sm font-medium">
                              {t("settings:securityPage.codeLabel")}
                            </FormLabel>
                            <FormControl>
                              <Input
                                inputMode="numeric"
                                maxLength={6}
                                placeholder="000000"
                                {...field}
                              />
                            </FormControl>
                            <FormMessage>
                              {fieldState.error?.message}
                            </FormMessage>
                          </FormItem>
                        )}
                      />
                      <Button type="submit" size="sm" disabled={isPending}>
                        {isPending
                          ? t("settings:securityPage.verifying")
                          : t("settings:securityPage.verifyButton")}
                      </Button>
                    </form>
                  </Form>
                </div>
              </>
            ) : null}
          </div>
        </div>
      </div>
    </>
  );
}
