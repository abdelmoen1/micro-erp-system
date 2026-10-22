import { useMutation, useQueryClient } from "@tanstack/react-query";
import { loginUser, registerStore } from "./api";
import { queryKeys } from "./queryClient";

// Auth mutations. On success the session is stored (api.js) and the cached current user is
// replaced, so no screen keeps showing a previous account.

export function useLoginMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: loginUser,
    onSuccess: (result) => {
      queryClient.clear();
      queryClient.setQueryData(queryKeys.me, result.user);
    },
  });
}

export function useRegisterMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: registerStore,
    onSuccess: (result) => {
      queryClient.clear();
      queryClient.setQueryData(queryKeys.me, result.user);
    },
  });
}
