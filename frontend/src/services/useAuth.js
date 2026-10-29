import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { authOptions, loginUser, registerStore } from "./api";
import { queryKeys } from "./queryClient";

// Auth mutations. On success the session is stored (api.js) and the cached current user is
// replaced, so no screen keeps showing a previous account.

function useSessionMutation(mutationFn) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn,
    onSuccess: (result) => {
      queryClient.clear();
      queryClient.setQueryData(queryKeys.me, result.user);
    },
  });
}

export const useLoginMutation = () => useSessionMutation(loginUser);
export const useRegisterMutation = () => useSessionMutation(registerStore);

/** Whether SMS codes are on (sign-up code, «forgot password», a new number). */
export const useAuthOptions = () => useQuery({ queryKey: ["auth-options"], queryFn: authOptions, staleTime: 5 * 60_000 });
