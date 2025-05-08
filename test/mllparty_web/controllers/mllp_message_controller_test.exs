defmodule MLLPartyWeb.MLLPMessageControllerTest do
  use MLLPartyWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  @moduletag capture_log: true

  @api_endpoint "/api/mllp_messages"
  @valid_hl7 HL7.Examples.wikipedia_sample_hl7()

  describe "POST #{@api_endpoint}" do
    setup do
      on_exit(fn ->
        MLLParty.ConnectionHub.reset()
      end)

      {:ok, %{conn: build_conn()}}
    end

    test "with missing `endpoint` param", %{conn: conn} do
      params = %{message: "some|hl7"}

      resp =
        conn
        |> post(@api_endpoint, params)
        |> json_response(400)

      assert resp == %{"message" => "Missing params: endpoint"}
    end

    test "with missing `message` param", %{conn: conn} do
      params = %{endpoint: "127.0.0.1:2575"}

      resp =
        conn
        |> post(@api_endpoint, params)
        |> json_response(400)

      assert resp == %{"message" => "Missing params: message"}
    end

    test "with invalid `endpoint` param", %{conn: conn} do
      for endpoint <- ["invalid.com", "127.0.0.1", ":3000"] do
        params = %{endpoint: endpoint, message: @valid_hl7}

        resp =
          conn
          |> post(@api_endpoint, params)
          |> json_response(400)

        assert resp == %{"message" => "Invalid `endpoint` param: #{endpoint}"}
      end
    end

    test "with invalid hl7 in `message` param", %{conn: conn} do
      params = %{endpoint: "127.0.0.1:2575", message: "some|invalid|hl7"}

      resp =
        conn
        |> post(@api_endpoint, params)
        |> json_response(400)

      assert resp == %{
               "message" => "Invalid HL7 in `message` param. Reason: missing_header"
             }
    end

    test "sending just to log", %{conn: conn} do
      original_log_level = Application.get_env(:logger, :level)
      Application.put_env(:logger, :level, :info)

      fun = fn ->
        params = %{endpoint: "log", message: @valid_hl7}

        resp =
          conn
          |> post(@api_endpoint, params)
          |> json_response(200)

        assert resp == %{"sent" => true}
      end

      assert capture_log(fun) =~ "Valid HL7 message received:"
      assert capture_log(fun) =~ @valid_hl7

      Application.put_env(:logger, :level, original_log_level)
    end

    test "sending valid HL7 to a non-listening mllp endpoint", %{conn: conn} do
      params = %{endpoint: "127.0.0.1:6090", message: @valid_hl7}

      resp =
        conn
        |> post(@api_endpoint, params)
        |> json_response(502)

      assert resp == %{"sent" => false, "message" => "connection refused"}
    end

    test "sending valid HL7 to a listening mllp endpoint", %{conn: conn} do
      {:ok, _r6090} = MLLP.Receiver.start(port: 6090, dispatcher: MLLP.EchoDispatcher)

      params = %{endpoint: "127.0.0.1:6090", message: @valid_hl7}

      resp =
        conn
        |> post(@api_endpoint, params)
        |> json_response(200)

      assert resp == %{
               "sent" => true,
               "acknowledgement_code" => "AA",
               "hl7_ack_message" => nil,
               "text_message" => "A real MLLP message dispatcher was not provided"
             }

      MLLP.Receiver.stop(6090)
    end
  end
end
